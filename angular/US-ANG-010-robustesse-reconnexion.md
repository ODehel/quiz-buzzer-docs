# US-ANG-010 — Robustesse et reconnexion

## 📋 Contexte projet

Voir [VISION.md](VISION.md) pour la description complète du projet et de ses quatre applications.

---

## 🎯 User Story

> **En tant que** maître de jeu,
> **je veux** que l'application se reconnecte automatiquement en cas de perte réseau, synchronise l'état de la partie et renouvelle son token sans intervention de ma part,
> **afin de** ne jamais perdre le contrôle d'une partie en cours à cause d'une instabilité réseau ou d'une expiration silencieuse.

---

## ✅ Critères d'acceptance

> 🧪 **Exigence de couverture** — Voir [CONVENTIONS-TECHNIQUES-ANGULAR.md](CONVENTIONS-TECHNIQUES-ANGULAR.md). Couverture `WebSocketService` (scénarios de reconnexion) ≥ 90 %. Couverture `AuthService` (refresh cycle complet) ≥ 90 %. Couverture `GameStateService` (dispatch `game_state_sync`) 100 %.

---

### Reconnexion automatique — `WebSocketService`

#### Backoff exponentiel

| # | Critère | Résultat attendu |
|---|---|---|
| CA-1 | Toute perte de connexion WebSocket (coupure réseau, timeout serveur, code de fermeture non-terminal) déclenche une tentative de reconnexion | Première tentative après 1 s, puis 2 s, 4 s, 8 s… plafonné à 30 s |
| CA-2 | Le backoff est réinitialisé à 1 s dès qu'une reconnexion aboutit à un `auth_success` | Le compteur de tentatives est remis à 0 |
| CA-3 | Pendant la fenêtre de reconnexion, `WebSocketService.isReconnecting()` est `true` | L'indicateur de connexion dans la topbar passe à orange "Reconnexion…" (conforme à US-ANG-002 CA-24) |
| CA-4 | À la reconnexion réussie, `WebSocketService.isConnected()` repasse à `true` | L'indicateur de connexion dans la topbar repasse au vert "Connecté" |

#### Codes de fermeture terminaux — pas de retry

| # | Critère | Résultat attendu |
|---|---|---|
| CA-5 | Code `4004` (session replaced — second onglet) : pas de reconnexion, navigation vers `/error` avec message "Cette session a été reprise dans un autre onglet" | Un seul onglet peut piloter une partie à la fois |
| CA-6 | Code `4001` (token invalide — cas non résolvable) : pas de reconnexion, navigation vers `/error` | Le token est structurellement invalide — un refresh ne résoudrait rien |

#### Codes de fermeture nécessitant un refresh avant retry

| # | Critère | Résultat attendu |
|---|---|---|
| CA-7 | Code `4002` (token expiré côté serveur) : `AuthService.refresh()` est appelé avant la reconnexion | Nouveau token obtenu via `POST /api/v1/token`, puis reconnexion avec `{ type: 'auth', token: <nouveau> }` |
| CA-8 | Si le refresh échoue (réseau indisponible) : backoff exponentiel sur le refresh lui-même (5 s entre tentatives, 3 essais max) | Après 3 échecs de refresh, navigation vers `/error` |

---

### Refresh silencieux du token — `AuthService`

#### Refresh proactif sur `token_expiring_soon`

| # | Critère | Résultat attendu |
|---|---|---|
| CA-9 | À la réception de `token_expiring_soon` via WebSocket, `AuthService.refresh()` est appelé en arrière-plan | `POST /api/v1/token` — aucune interruption visible, aucun toast |
| CA-10 | En cas de succès, `WebSocketService` envoie immédiatement `{ type: 'auth_refresh', token: '<nouveau>' }` sur la connexion WebSocket **existante** | La connexion n'est pas interrompue — conforme à l'US-021 serveur |
| CA-11 | À la réception de `auth_success` après `auth_refresh` : `AuthService` stocke le nouveau token, `WebSocketService.isReady` reste `true` | Le `expires_in` du nouveau token repart de son maximum |
| CA-12 | En cas d'échec de `AuthService.refresh()` : nouvelle tentative après 5 s, jusqu'à 3 fois | Après 3 échecs, la connexion WebSocket est fermée intentionnellement — le backoff exponentiel de reconnexion reprend |

#### Refresh réactif sur `token_expired`

| # | Critère | Résultat attendu |
|---|---|---|
| CA-13 | À la réception de `token_expired` : traitement identique au code de fermeture `4002` — refresh puis reconnexion complète | `token_expired` est le signal que la connexion va être fermée côté serveur |

---

### Synchronisation de l'état après reconnexion — `GameStateService`

#### Réception de `game_state_sync`

| # | Critère | Résultat attendu |
|---|---|---|
| CA-14 | À la réception de `game_state_sync` avec `status: 'PENDING'`, `GameStateService.dispatch()` met à jour les participants et les buzzers connectés | L'UI du lobby est automatiquement cohérente — pas de navigation |
| CA-15 | À la réception de `game_state_sync` avec `status: 'OPEN'`, le signal est mis à jour avec les participants et les scores cumulés | Si l'écran courant est `/pilot/lobby`, l'`effect()` déclenche la navigation vers `/pilot/play` |
| CA-16 | À la réception de `game_state_sync` avec `status: 'QUESTION_TITLE'` ou `'QUESTION_CLOSED'`, le signal est mis à jour sans `started_at` ni `time_limit` | L'écran MCQ affiche le titre ou le récapitulatif de correction sans chrono actif |
| CA-17 | À la réception de `game_state_sync` avec `status: 'QUESTION_OPEN'` ou `'QUESTION_BUZZED'` incluant `started_at` et `time_limit`, le chrono local est recalculé | `remaining = time_limit - (Date.now() - new Date(started_at).getTime()) / 1000` — puis le chrono reprend normalement |
| CA-18 | À la réception de `game_state_sync` avec `status: 'COMPLETED'`, navigation automatique vers `/pilot/results` | Via `effect()` dans `PlayComponent` |
| CA-19 | À la réception de `game_state_sync` avec `status: 'IN_ERROR'`, le banner d'erreur bloquant est affiché | Conforme à US-ANG-008 CA-7 |
| CA-20 | Si aucune partie active n'existe au moment de la reconnexion (`game_state_sync` non reçu), `GameStateService.reset()` est appelé | L'état local est vidé — le maître de jeu est redirigé vers `/dashboard` si l'écran courant est dans `/pilot/*` |

#### Recalcul du chrono après reconnexion

| # | Critère | Résultat attendu |
|---|---|---|
| CA-21 | La fonction de recalcul du temps restant est une **fonction pure testable indépendamment** du composant | `computeRemaining(startedAt: string, timeLimit: number): number` — exportée depuis un fichier utilitaire |
| CA-22 | Si `remaining < 0` au moment du recalcul (question expirée pendant la déconnexion), `remaining` est fixé à 0 | Pas de valeur négative affichée |
| CA-23 | Si `remaining > timeLimit` au moment du recalcul (horloge désynchronisée), `remaining` est plafonné à `timeLimit` | Valeur défensive — évite un chrono supérieur au temps initial |

---

### Gestion de l'état `IN_ERROR`

| # | Critère | Résultat attendu |
|---|---|---|
| CA-24 | Si `GameStateService.status()` passe à `IN_ERROR` pendant le pilotage, un banner rouge bloquant est affiché par-dessus `PlayComponent` | Message : "La partie est en erreur serveur — le jeu a été interrompu" |
| CA-25 | Le banner `IN_ERROR` propose un bouton "Voir les résultats partiels" | Navigation vers `/games/:id/results` — `GameResultsComponent` appelle `GET /api/v1/games/:id/results` |
| CA-26 | Aucune action de pilotage n'est possible depuis l'état `IN_ERROR` | Tous les boutons de pilotage sont masqués ou désactivés |

---

### Guards et navigation défensive

| # | Critère | Résultat attendu |
|---|---|---|
| CA-27 | `activeGameGuard` redirige vers `/dashboard` si `GameStateService.isPiloting()` est `false` à la navigation | Le guard est évalué à chaque navigation vers `/pilot/*` |
| CA-28 | `noActiveGameGuard` redirige vers `/pilot/play` si `GameStateService.isPiloting()` est `true` à la navigation vers `/content/*` | Empêche l'accès au backoffice pendant une partie active |
| CA-29 | Si `noActiveGameGuard` redirige, un toast informatif "Vous ne pouvez pas accéder au contenu pendant une partie" est affiché | L'utilisateur comprend pourquoi la navigation a été bloquée |
| CA-30 | `authGuard` redirige vers `/error` si `AuthService.isReady()` est `false` | Garde défensive — ne devrait pas arriver après un démarrage réussi |

---

### Tests d'intégration end-to-end (Sprint 8)

| # | Critère | Résultat attendu |
|---|---|---|
| CA-31 | Scénario MCQ complet mocké : démarrage → `trigger_title` → `trigger_choices` → réponses → `all_answered` → `trigger_correction` → `trigger_next_question` → … → `COMPLETED` | Tous les signals de `GameStateService` sont dans l'état attendu à chaque étape |
| CA-32 | Scénario SPEED complet mocké : démarrage → `trigger_title` → `buzz_locked` → `validate_answer` → `question_result_summary` → `COMPLETED` | Idem |
| CA-33 | Scénario de reconnexion mocké en `QUESTION_OPEN` : coupure WebSocket → reconnexion → `game_state_sync` avec `started_at` → chrono recalculé correctement | `computeRemaining()` testée isolément avec `jest.useFakeTimers()` |
| CA-34 | Scénario de refresh token mocké : `token_expiring_soon` → `AuthService.refresh()` → `auth_refresh` → `auth_success` → nouveau `expires_in` | Le cycle complet est testé sans timer réel |

---

## 🔧 Spécifications techniques

Voir [CONVENTIONS-TECHNIQUES-ANGULAR.md](CONVENTIONS-TECHNIQUES-ANGULAR.md) pour la stack complète, les principes et les conventions de code.

### `WebSocketService` — gestion complète des codes de fermeture

```typescript
private handleClose(code: number): void {
  this.isConnected.set(false);
  this.isReconnecting.set(true);

  // Codes terminaux — pas de retry
  if (code === 4004) {
    this.router.navigate(['/error'], {
      state: { message: 'Cette session a été reprise dans un autre onglet.' }
    });
    return;
  }
  if (code === 4001) {
    this.router.navigate(['/error'], {
      state: { message: 'Erreur d\'authentification WebSocket.' }
    });
    return;
  }

  // Refresh requis avant retry
  if (code === 4002) {
    this.authService.refresh()
      .then(() => this.reconnect())
      .catch(() => this.scheduleReconnect());
    return;
  }

  // Tous les autres codes → backoff exponentiel
  this.scheduleReconnect();
}

private scheduleReconnect(): void {
  const delay = Math.min(1000 * Math.pow(2, this.attempt), 30_000);
  this.attempt++;
  timer(delay)
    .pipe(takeUntil(this.destroy$))
    .subscribe(() => this.reconnect());
}
```

### `computeRemaining()` — fonction pure utilitaire

```typescript
// src/app/core/utils/timer.utils.ts

/**
 * Calcule le temps restant en secondes depuis un horodatage de début.
 * Toujours dans l'intervalle [0, timeLimit].
 */
export function computeRemaining(startedAt: string, timeLimit: number): number {
  const elapsed = (Date.now() - new Date(startedAt).getTime()) / 1000;
  return Math.max(0, Math.min(timeLimit, timeLimit - elapsed));
}
```

```typescript
// timer.utils.spec.ts
describe('computeRemaining', () => {
  it('retourne le temps restant correct', () => {
    const startedAt = new Date(Date.now() - 10_000).toISOString(); // 10s écoulées
    expect(computeRemaining(startedAt, 30)).toBeCloseTo(20, 0);
  });

  it('ne retourne jamais une valeur négative', () => {
    const startedAt = new Date(Date.now() - 60_000).toISOString(); // 60s écoulées
    expect(computeRemaining(startedAt, 30)).toBe(0);
  });

  it('est plafonné à timeLimit si l\'horloge est désynchronisée', () => {
    const startedAt = new Date(Date.now() + 5_000).toISOString(); // dans le futur
    expect(computeRemaining(startedAt, 30)).toBe(30);
  });
});
```

### `GameStateService.dispatch()` — traitement de `game_state_sync`

```typescript
private onGameStateSync(msg: GameStateSyncMessage): void {
  const { status, game_id, question_index, quiz_id, participants,
          started_at, time_limit } = msg;

  this._state.update(s => ({
    ...s,
    gameId:           game_id,
    status,
    quizId:           quiz_id,
    questionIndex:    question_index,
    participants:     participants.map(p => ({
      order:            p.order,
      name:             p.name,
      cumulative_score: p.cumulative_score
    })),
    startedAt:        started_at ?? s.startedAt,
    timeLimit:        time_limit ?? s.timeLimit,
    remainingSeconds: started_at && time_limit
      ? computeRemaining(started_at, time_limit)
      : s.remainingSeconds
  }));

  // Réinitialisation si statut non-actif
  if (!['OPEN', 'PENDING', 'QUESTION_TITLE', 'QUESTION_OPEN',
         'QUESTION_BUZZED', 'QUESTION_CLOSED'].includes(status)) {
    this._state.set(INITIAL_STATE);
  }
}
```

### `ErrorComponent` — messages contextuels

```typescript
@Component({ ... })
export class ErrorComponent {
  protected readonly message = signal<string>(
    inject(Router).getCurrentNavigation()?.extras.state?.['message']
    ?? 'Une erreur inattendue s\'est produite.'
  );
}
```

### Structure des fichiers Sprint 8

```
src/app/
  core/
    utils/
      timer.utils.ts          ← computeRemaining() — fonction pure
      timer.utils.spec.ts     ← tests unitaires isolés
    services/
      auth.service.ts         ← compléter le cycle refresh (CA-9 à CA-13)
      websocket.service.ts    ← compléter les codes de fermeture (CA-5 à CA-8)
      game-state.service.ts   ← compléter dispatch game_state_sync (CA-14 à CA-20)
  error/
    error.component.ts        ← messages contextuels (CA-5, CA-6)
```

---

## 📐 Périmètre

| Inclus | Exclu |
|---|---|
| Reconnexion automatique avec backoff exponentiel (1 s → 30 s max) | Reconnexion manuelle par l'utilisateur |
| Traitement différencié des codes de fermeture `4001`, `4002`, `4004` | Gestion du code `4003` (auth timeout — couvert par US-ANG-001) |
| Refresh proactif sur `token_expiring_soon` avec `auth_refresh` sur WS existant | Refresh token REST (YAGNI) |
| Refresh réactif sur `token_expired` avec reconnexion complète | |
| Restauration de l'état via `game_state_sync` pour tous les statuts | Restauration de l'historique des `question_result_summary` après reconnexion (YAGNI) |
| Recalcul du chrono via `computeRemaining()` (fonction pure testable) | Compensation de la latence réseau dans le chrono (YAGNI) |
| Gestion de `IN_ERROR` avec banner bloquant et accès aux résultats partiels | Récupération automatique de l'état `IN_ERROR` (impossible — le serveur a échoué) |
| Guards `activeGameGuard` et `noActiveGameGuard` avec toasts informatifs | |
| Tests d'intégration end-to-end (scénarios MCQ, SPEED, reconnexion, refresh) | Déploiement / CI-CD |

---

## 🔍 Points de vigilance

### `computeRemaining` — test avec `jest.useFakeTimers()`

Les tests de reconnexion impliquant des timers (`scheduleReconnect`, backoff) doivent utiliser `jest.useFakeTimers()` pour avancer le temps artificiellement. Sans cela, les tests attendraient jusqu'à 30 secondes réelles — inacceptable dans une suite CI. La fonction `computeRemaining()` étant pure (pas de `Date.now()` interne), elle peut être testée directement en passant un `startedAt` calculé à partir d'une date fixe.

### Pas de retry infini sans plafond

Le backoff est plafonné à 30 s mais la reconnexion est tentée indéfiniment — tant que l'utilisateur garde l'onglet ouvert. Sur un réseau WiFi local, une interruption prolongée est rare et l'utilisateur préfère que l'application reprenne seule plutôt que d'afficher une page d'erreur définitive.

### `game_state_sync` sans partie active

Si le serveur ne retourne pas de `game_state_sync` après la reconnexion (aucune partie active), l'absence de signal doit être détectée via un timeout de 2 s après `auth_success`, puis `GameStateService.syncInitial()` (GET REST) est appelé — chemin identique à l'`APP_INITIALIZER`.

### `IN_ERROR` — irréversible côté Angular

L'état `IN_ERROR` est terminal dans la machine à états du serveur. Angular ne peut pas en sortir via un message WebSocket — la seule issue est la suppression de la partie via `DELETE /api/v1/games/:id`. Le banner `IN_ERROR` ne propose donc pas de bouton "Réessayer" — ce serait trompeur.

---

## 🔗 Documents liés

| Document | Contenu |
|---|---|
| [VISION.md](VISION.md) | Description complète du projet |
| [CONVENTIONS-TECHNIQUES-ANGULAR.md](CONVENTIONS-TECHNIQUES-ANGULAR.md) | Stack, principes, conventions de code |
| [US-ANG-001 — Initialisation](US-ANG-001-init-session.md) | Backoff exponentiel, `APP_INITIALIZER`, base du refresh |
| [US-ANG-008 — Pilotage](US-ANG-008-pilotage.md) | Reconnexion pendant le pilotage, banner `IN_ERROR` |
| [US-009 — Connexion WebSocket (serveur)](US-009-websocket-connection.md) | Codes de fermeture `4001`–`4004` |
| [US-019 — Reprise après crash (serveur)](US-019-game-recovery.md) | Format `game_state_sync` avec `started_at` et `time_limit` |
| [US-021 — Refresh JWT WebSocket (serveur)](US-021-token-refresh.md) | Protocole `token_expiring_soon` / `auth_refresh` / `token_expired` |

---

**Dernière mise à jour** : 2026-03-28
**Statut** : Implémentée (Sprint 8)
**Sprint** : 8
