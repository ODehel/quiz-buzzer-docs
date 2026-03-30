# US-ANG-007 — Lobby d'attente et démarrage de partie

## 📋 Contexte projet

Voir [VISION.md](VISION.md) pour la description complète du projet et de ses quatre applications.

---

## 🎯 User Story

> **En tant que** maître de jeu,
> **je veux** surveiller les connexions des buzzers avant le démarrage, ajuster la liste des participants si besoin, puis lancer la partie quand tout est prêt,
> **afin de** démarrer dans les meilleures conditions avec tous les joueurs connectés.

---

## ✅ Critères d'acceptance

> 🧪 **Exigence de couverture** — Voir [CONVENTIONS-TECHNIQUES-ANGULAR.md](CONVENTIONS-TECHNIQUES-ANGULAR.md). Couverture `LobbyComponent` ≥ 70 %.

---

### Accès au lobby

| # | Critère | Résultat attendu |
|---|---|---|
| CA-1 | `/pilot/lobby` est accessible uniquement si `GameStateService.isPiloting()` est `true` | `activeGameGuard` redirige vers `/dashboard` si aucune partie active |
| CA-2 | Si le statut de la partie est `OPEN` ou un état `QUESTION_*` à l'arrivée sur `/pilot/lobby`, redirection immédiate vers `/pilot/play` | La partie a déjà démarré — le lobby n'est plus pertinent |
| CA-3 | Si le statut est `PENDING`, le lobby s'affiche normalement | Cas nominal |

---

### Affichage du lobby

#### En-tête

| # | Critère | Résultat attendu |
|---|---|---|
| CA-4 | Le nom du quiz associé à la partie est affiché | Issu de `GameStateService.state().quizId` enrichi via `QuizService.getById()` au montage |
| CA-5 | Le nombre de participants configurés est affiché | Issu de `GameStateService.state().participants.length` |

#### Barre de readiness

| # | Critère | Résultat attendu |
|---|---|---|
| CA-6 | Une barre de readiness indique si le nombre de buzzers connectés est suffisant | Verte si `connectedBuzzers.length >= participants.length`, orange sinon |
| CA-7 | Le sous-titre indique le nombre de buzzers connectés et le nombre de participants attendus | Ex. : "3 buzzers connectés sur 3 attendus" |
| CA-8 | La barre se met à jour en temps réel sans rechargement | Source : `GameStateService.connectedBuzzers()` — signal mis à jour par `WebSocketService` |

#### Panneau des participants

| # | Critère | Résultat attendu |
|---|---|---|
| CA-9 | La liste des participants est affichée avec leur ordre, leur nom et un indicateur de buzzer associé | Le N-ième participant est associé au N-ième buzzer connecté par ordre de connexion |
| CA-10 | Si moins de buzzers sont connectés que de participants, les participants sans buzzer affichent "Non connecté" en gris | Pas d'erreur bloquante — information visible sans empêcher le démarrage |

#### Panneau des buzzers connectés

| # | Critère | Résultat attendu |
|---|---|---|
| CA-11 | La liste des buzzers connectés est affichée avec leur username | Source : `GameStateService.connectedBuzzers()` |
| CA-12 | Les buzzers non connectés (slots libres jusqu'à 10) sont affichés grisés | Affiche les 10 slots potentiels avec leur statut |
| CA-13 | La liste des buzzers se met à jour en temps réel | Réactif sur `GameStateService.connectedBuzzers()` — pas de polling |

---

### Actions dans le lobby

#### Démarrage de la partie

| # | Critère | Résultat attendu |
|---|---|---|
| CA-14 | Le bouton "Démarrer la partie" est toujours visible et cliquable, quelle que soit la readiness | La readiness est informative — elle n'empêche pas le démarrage |
| CA-15 | Un clic sur "Démarrer la partie" appelle `POST /api/v1/games/:id/start` | L'ID est lu depuis `GameStateService.state().gameId` |
| CA-16 | En cas de `200 OK`, Angular attend la réception de `game_state_sync` avec `status: 'OPEN'` avant de naviguer | La transition côté Angular est pilotée par le WebSocket, pas par la réponse REST |
| CA-17 | À la réception de `game_state_sync` avec `status: 'OPEN'`, navigation vers `/pilot/play` | Déclenchée par un `effect()` sur `GameStateService.status()` dans `LobbyComponent` |
| CA-18 | En cas d'erreur réseau ou `5xx` lors du POST : toast d'erreur "Impossible de démarrer la partie" | Le bouton redevient actif — pas de navigation |

#### Annulation de la partie

| # | Critère | Résultat attendu |
|---|---|---|
| CA-19 | Le bouton "Annuler la partie" est visible dans le lobby | Toujours présent |
| CA-20 | Un clic ouvre `ConfirmDialogComponent` avec le message "Supprimer la partie en attente ?" | La confirmation est requise |
| CA-21 | Après confirmation, `DELETE /api/v1/games/:id` est appelé | En cas de `204` : `GameStateService.reset()` est appelé, navigation vers `/games` avec toast "Partie annulée" |
| CA-22 | En cas d'erreur réseau ou `5xx` : toast d'erreur générique | Le dialog se ferme — pas de navigation |

---

### Reconnexion WebSocket pendant le lobby

| # | Critère | Résultat attendu |
|---|---|---|
| CA-23 | Si le WebSocket se reconnecte en `PENDING`, `game_state_sync { status: 'PENDING' }` est reçu | `GameStateService.dispatch()` traite le message — le lobby reste affiché, participants et buzzers resynchronisés |
| CA-24 | Si `game_state_sync { status: 'OPEN' }` est reçu pendant le lobby, navigation automatique vers `/pilot/play` | L'`effect()` sur `GameStateService.status()` déclenche la navigation |

---

## 🔧 Spécifications techniques

Voir [CONVENTIONS-TECHNIQUES-ANGULAR.md](CONVENTIONS-TECHNIQUES-ANGULAR.md) pour la stack complète, les principes et les conventions de code.

### `LobbyComponent` — structure

```typescript
@Component({
  selector: 'app-lobby',
  standalone: true,
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class LobbyComponent {
  protected readonly gs         = inject(GameStateService);
  private  readonly ws          = inject(WebSocketService);
  private  readonly gameService = inject(GameService);
  private  readonly quizService = inject(QuizService);
  private  readonly router      = inject(Router);

  protected readonly quizName  = signal<string | null>(null);
  protected readonly isStarting = signal(false);
  protected readonly isDeleting = signal(false);

  protected readonly isReady = computed(() =>
    this.gs.connectedBuzzers().length >= this.gs.state().participants.length
  );

  protected readonly participantsWithBuzzer = computed(() => {
    const participants = this.gs.state().participants;
    const buzzers      = this.gs.connectedBuzzers();
    return participants.map((p, i) => ({
      ...p,
      buzzerUsername: buzzers[i] ?? null
    }));
  });

  constructor() {
    if (this.gs.status() !== 'PENDING') {
      this.router.navigate(['/pilot/play']);
      return;
    }

    const quizId = this.gs.state().quizId;
    if (quizId) {
      this.quizService.getById(quizId)
        .pipe(takeUntilDestroyed(inject(DestroyRef)))
        .subscribe(q => this.quizName.set(q.name));
    }

    effect(() => {
      const s = this.gs.status();
      if (s === 'OPEN' || s?.startsWith('QUESTION_')) {
        this.router.navigate(['/pilot/play']);
      }
    }, { injector: inject(Injector) });
  }

  async onStartGame(): Promise<void> {
    const gameId = this.gs.state().gameId;
    if (!gameId) return;
    this.isStarting.set(true);
    try {
      await this.gameService.start(gameId);
      // Navigation déclenchée par l'effect() sur game_state_sync WebSocket
    } catch {
      this.isStarting.set(false);
    }
  }

  async onDeleteGame(): Promise<void> {
    const gameId = this.gs.state().gameId;
    if (!gameId) return;
    this.isDeleting.set(true);
    try {
      await this.gameService.delete(gameId);
      this.gs.reset();
      this.router.navigate(['/games']);
    } catch {
      this.isDeleting.set(false);
    }
  }
}
```

### `GameService.start()` — transition `PENDING → OPEN`

```typescript
async start(id: string): Promise<Game> {
  return firstValueFrom(
    this.http.post<Game>(`${this.baseUrl}/${id}/start`, {})
  );
}
```

### Endpoints consommés

| Appel | Endpoint | US serveur | Contexte |
|---|---|---|---|
| Nom du quiz | `GET /api/v1/quizzes/:id` | US-008 | Affichage du nom en en-tête |
| Démarrage | `POST /api/v1/games/:id/start` | US-010 | Bouton "Démarrer" |
| Suppression | `DELETE /api/v1/games/:id` | US-010 | Bouton "Annuler" |

### Messages WebSocket traités (via `GameStateService`)

| Message reçu | Effet côté Angular |
|---|---|
| `game_state_sync { status: 'PENDING' }` | Mise à jour des participants et buzzers — lobby inchangé |
| `game_state_sync { status: 'OPEN' }` | Transition vers `/pilot/play` via `effect()` |
| `auth_success { role: 'buzzer' }` | `GameStateService.addConnectedBuzzer(username)` |
| Déconnexion buzzer | `GameStateService.removeConnectedBuzzer(username)` |

---

## 📐 Périmètre

| Inclus | Exclu |
|---|---|
| Affichage temps réel des buzzers connectés | Limitation du démarrage si buzzers insuffisants |
| Barre de readiness informative | Attribution forcée buzzers ↔ participants (YAGNI) |
| Démarrage via `POST /api/v1/games/:id/start` | Démarrage automatique si tous connectés (YAGNI) |
| Navigation automatique sur `game_state_sync { status: 'OPEN' }` | Édition des participants depuis le lobby (YAGNI) |
| Annulation de la partie avec `DELETE` | Annulation depuis l'écran de pilotage |
| Reconnexion WebSocket transparente | Reconnexion manuelle explicite |
| Tests unitaires et d'intégration (couverture ≥ 70 %) | Déploiement / CI-CD |

---

## 🔍 Points de vigilance

### Navigation déclenchée par le WebSocket, pas par le REST

Le `POST /api/v1/games/:id/start` est une instruction au serveur — Angular ne navigue **pas** immédiatement après la réponse `200 OK`. La navigation est déclenchée par l'`effect()` réagissant à `GameStateService.status()`, mis à jour par `game_state_sync`. Ce délai garantit que l'état local est synchronisé avec l'état serveur avant que `PlayComponent` ne se monte.

### `effect()` dans le constructeur — pattern Angular 18

L'utilisation de `effect()` dans un constructeur requiert `{ injector: inject(Injector) }`. Sans ce paramètre, Angular lève une erreur car les effects doivent être créés dans un contexte d'injection.

### Association participant ↔ buzzer — caractère informatif

L'association entre le N-ième participant et le N-ième buzzer est une convention d'affichage. Le serveur gère uniquement des usernames — il ne connaît pas quelle instance de buzzer physique correspond à quel participant.

---

## 🔗 Documents liés

| Document | Contenu |
|---|---|
| [VISION.md](VISION.md) | Description complète du projet |
| [CONVENTIONS-TECHNIQUES-ANGULAR.md](CONVENTIONS-TECHNIQUES-ANGULAR.md) | Stack, principes, conventions de code |
| [US-ANG-001 — Initialisation](US-ANG-001-init-session.md) | `WebSocketService`, `GameStateService` |
| [US-ANG-006 — Liste des parties et création](US-ANG-006-liste-parties-creation.md) | Flux précédent |
| [US-ANG-008 — Pilotage](US-ANG-008-pilotage.md) | Suite immédiate après démarrage |
| [US-010 — CRUD des parties (serveur)](US-010-game-crud.md) | Endpoints POST start et DELETE |

---

**Dernière mise à jour** : 2026-03-28
**Statut** : Implémentée — 26 tests, couverture 94.59% statements / 98.48% lines
**Sprint** : 5
