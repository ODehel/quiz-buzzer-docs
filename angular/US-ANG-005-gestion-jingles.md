# US-ANG-005 — Gestion des jingles

## 📋 Contexte projet

Voir [VISION.md](VISION.md) pour la description complète du projet et de ses quatre applications.

---

## 🎯 User Story

> **En tant que** maître de jeu,
> **je veux** uploader et supprimer des jingles dans le backoffice, et les diffuser vers les buzzers pendant une partie,
> **afin d'** animer mes sessions avec des sons personnalisés.

---

## ✅ Critères d'acceptance

> 🧪 **Exigence de couverture** — Voir [CONVENTIONS-TECHNIQUES-ANGULAR.md](CONVENTIONS-TECHNIQUES-ANGULAR.md). Couverture `SoundService` ≥ 80 %. Couverture `SoundListComponent` et `SoundPanelComponent` ≥ 70 %.

---

### Bibliothèque de jingles — `SoundListComponent`

#### Chargement initial

| # | Critère | Résultat attendu |
|---|---|---|
| CA-1 | Au chargement, `GET /api/v1/sounds?page=1&limit=20` est appelé | Liste paginée triée par date décroissante |
| CA-2 | Chaque ligne affiche : nom du jingle, date d'upload | Pas d'aperçu audio inline — YAGNI |
| CA-3 | Si la liste est vide, un message d'invitation "Aucun jingle — uploadez votre premier jingle" est affiché | Pas de tableau vide |

#### Upload d'un jingle

| # | Critère | Résultat attendu |
|---|---|---|
| CA-4 | Un bouton "Uploader un jingle" ouvre un dialogue d'upload avec un champ nom et une zone de dépôt de fichier | Le nom est prérempli avec le nom du fichier sélectionné (sans extension), modifiable |
| CA-5 | Avant l'envoi, une validation locale vérifie que la taille du fichier est ≤ 10 Mo et que le MIME est `audio/mpeg`, `audio/wav` ou `audio/ogg` | Message d'erreur inline si invalide — aucun appel réseau |
| CA-6 | Si valide, `POST /api/v1/sounds` est appelé avec `multipart/form-data` contenant `name` et `file` | En cas de `201` : la liste est rechargée, toast "Jingle ajouté", dialogue fermé |
| CA-7 | En cas de `409 SOUND_ALREADY_EXISTS` : message d'erreur inline "Un jingle porte déjà ce nom" | Le dialogue reste ouvert |
| CA-8 | En cas de `413 FILE_TOO_LARGE` retourné par le serveur : message d'erreur inline "Fichier trop volumineux" | Le dialogue reste ouvert |

#### Suppression

| # | Critère | Résultat attendu |
|---|---|---|
| CA-9 | Le bouton "Supprimer" ouvre `ConfirmDialogComponent` avec le nom du jingle | La confirmation est requise avant tout appel réseau |
| CA-10 | Après confirmation, `DELETE /api/v1/sounds/:id` est appelé | En cas de `204` : la liste est rechargée avec toast "Jingle supprimé" |

---

### Panneau de sons pendant le pilotage — `SoundPanelComponent`

Ce composant est intégré dans la colonne droite de `PlayComponent`. Il est visible à tous les états actifs de la partie.

#### Sons système

| # | Critère | Résultat attendu |
|---|---|---|
| CA-11 | Deux boutons sont affichés en permanence : "Waiting" et "Suspense" | Ces sons sont déclenchables à tout moment pendant la partie |
| CA-12 | Un clic sur "Waiting" envoie `{ "type": "trigger_system_sound", "sound_id": "WAITING" }` via `WebSocketService.send()` | Broadcast à tous les buzzers — pas de `targets` dans le message |
| CA-13 | Un clic sur "Suspense" envoie `{ "type": "trigger_system_sound", "sound_id": "SUSPENSE" }` via `WebSocketService.send()` | Broadcast à tous les buzzers — pas de `targets` dans le message |
| CA-14 | Si le serveur retourne `error { code: "UNKNOWN_SYSTEM_SOUND" }`, un toast d'erreur discret est affiché | Cas théoriquement impossible mais géré défensivement |

#### Diffusion d'un jingle personnalisé

| # | Critère | Résultat attendu |
|---|---|---|
| CA-15 | Un select liste les jingles disponibles, chargés depuis `SoundService.getAll()` au montage du composant | `GET /api/v1/sounds?limit=100` — liste complète sans pagination dans ce contexte |
| CA-16 | Un select secondaire permet de cibler un ou plusieurs buzzers connectés, ou "Tous" (broadcast) | Liste des buzzers issue de `GameStateService.connectedBuzzers()` — mise à jour en temps réel |
| CA-17 | Un clic sur "Envoyer" envoie `{ "type": "play_sound", "sound_id": "<id>", "targets": [...] }` via `WebSocketService.send()` | Si "Tous" est sélectionné : le champ `targets` est omis du message (broadcast) |
| CA-18 | Si aucun jingle n'est sélectionné dans le select, le bouton "Envoyer" est désactivé | `disabled` calculé depuis un `computed` local |
| CA-19 | Si le serveur retourne `error { code: "SOUND_NOT_FOUND" }` : toast d'erreur "Jingle introuvable sur le serveur" | Le jingle a peut-être été supprimé entre le chargement du composant et la diffusion |

---

## 🔧 Spécifications techniques

Voir [CONVENTIONS-TECHNIQUES-ANGULAR.md](CONVENTIONS-TECHNIQUES-ANGULAR.md) pour la stack complète, les principes et les conventions de code.

### `SoundService` — interface publique

```typescript
@Injectable({ providedIn: 'root' })
export class SoundService {
  getAll(params?: { page?: number; limit?: number }): Observable<PagedResponse<Sound>>;
  upload(name: string, file: File): Promise<Sound>;
  delete(id: string): Promise<void>;
}
```

### `SoundPanelComponent` — state local

```typescript
protected readonly gs          = inject(GameStateService);
protected readonly ws          = inject(WebSocketService);
private  readonly soundService = inject(SoundService);

protected readonly sounds          = signal<Sound[]>([]);
protected readonly selectedId      = signal<string | null>(null);
protected readonly selectedTargets = signal<string[] | null>(null);
protected readonly canSend         = computed(() => this.selectedId() !== null);
```

### Construction du message `play_sound`

```typescript
onSendJingle(): void {
  const id = this.selectedId();
  if (!id) return;
  const targets = this.selectedTargets();
  const msg: OutboundMessage = targets?.length
    ? { type: 'play_sound', sound_id: id, targets }
    : { type: 'play_sound', sound_id: id };
  this.ws.send(msg);
}
```

### Interface `Sound`

```typescript
export interface Sound {
  id:         string;
  name:       string;
  filename:   string;
  url:        string;
  created_at: string;
}
```

### Endpoints consommés

| Appel | Endpoint | US serveur | Contexte |
|---|---|---|---|
| Liste des jingles | `GET /api/v1/sounds` | US-017 | `SoundListComponent` et `SoundPanelComponent` |
| Upload | `POST /api/v1/sounds` | US-017 | `SoundListComponent` uniquement |
| Suppression | `DELETE /api/v1/sounds/:id` | US-017 | `SoundListComponent` uniquement |

### Messages WebSocket envoyés

| Message | Déclencheur | Contexte |
|---|---|---|
| `trigger_system_sound { sound_id: "WAITING" }` | Bouton "Waiting" | `SoundPanelComponent` |
| `trigger_system_sound { sound_id: "SUSPENSE" }` | Bouton "Suspense" | `SoundPanelComponent` |
| `play_sound { sound_id, targets? }` | Bouton "Envoyer" | `SoundPanelComponent` |

---

## 📐 Périmètre

| Inclus | Exclu |
|---|---|
| Upload de jingles (mp3, wav, ogg ≤ 10 Mo) avec validation locale | Prévisualisation audio dans le navigateur (YAGNI) |
| Liste paginée des jingles avec suppression | Renommage d'un jingle (pas de PUT côté serveur) |
| Sons système manuels `WAITING` et `SUSPENSE` depuis le pilotage | Tous les autres sons système (déclenchés automatiquement par le serveur) |
| Diffusion de jingles vers buzzers ciblés ou broadcast | Confirmation de lecture côté buzzer (hors périmètre Angular) |
| Rechargement de la liste jingles au montage de `SoundPanelComponent` | Rechargement en temps réel pendant le pilotage (YAGNI) |
| Gestion de `SOUND_NOT_FOUND` WebSocket avec toast | |
| Tests unitaires et d'intégration (couverture ≥ 70 %) | Déploiement / CI-CD |

---

## 🔍 Points de vigilance

### `SoundPanelComponent` — chargement unique au montage

La liste des jingles est chargée une seule fois au montage avec `limit=100`. Si un jingle est uploadé dans le backoffice pendant une partie en cours (scénario rare), il n'apparaîtra pas dans le select. Ce compromis est intentionnel (KISS).

### URL du jingle — relative vs absolue

Le serveur retourne une URL **relative** dans la réponse REST. C'est le serveur qui construit l'URL absolue lors de la diffusion WebSocket (`play_sound_url`) destinée aux buzzers. Angular ne manipule jamais l'URL absolue du fichier audio.

### Ciblage des buzzers — cohérence avec `GameStateService`

Si un buzzer se déconnecte entre le moment où l'utilisateur ouvre le select et celui où il clique "Envoyer", le serveur ignorera silencieusement le buzzer absent (`SOUND_TARGET_NOT_CONNECTED`).

---

## 🔗 Documents liés

| Document | Contenu |
|---|---|
| [VISION.md](VISION.md) | Description complète du projet |
| [CONVENTIONS-TECHNIQUES-ANGULAR.md](CONVENTIONS-TECHNIQUES-ANGULAR.md) | Stack, principes, conventions de code |
| [US-ANG-001 — Initialisation](US-ANG-001-init-session.md) | `WebSocketService` |
| [US-017 — Gestion des jingles (serveur)](US-017-jingles-management.md) | Endpoints REST et messages WebSocket |
| [US-018 — Sons système (serveur)](US-018-system-sounds-trigger.md) | Format `trigger_system_sound` |

---

**Dernière mise à jour** : 2026-03-28
**Statut** : Rédigée — en attente d'implémentation (Sprint 4)
**Sprint** : 4
