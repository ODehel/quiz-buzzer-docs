# ARCHITECTURE-TECHNIQUE-ANGULAR.md

## 📋 Stack et dépendances

| Élément | Choix | Justification |
|---|---|---|
| Angular | 18 LTS | Standalone components, Signals stables, pas de NgModules |
| State management | Angular Signals | État discret par événements, rendu fin, pas de flux continu |
| WebSocket | RxJS `webSocket` + `retryWhen` | Reconnexion, backoff exponentiel — RxJS excelle ici |
| HTTP | `HttpClient` + `APP_INITIALIZER` | Auto-login au boot, intercepteur Bearer global |
| Routing | Angular Router, lazy loading par zone | Un bundle par zone fonctionnelle |
| Drag-and-drop (compositeur quiz) | `@angular/cdk/drag-drop` | CDK officiel, pas de dépendance tierce |
| Tests | Jest + Angular Testing Library | Cohérence avec le serveur Node.js |

---

## 🗂️ Structure complète du projet

```
src/
├── app/
│   │
│   ├── core/                          ← Singletons injectés en root
│   │   ├── models/                    ← Interfaces TypeScript
│   │   │   ├── api.models.ts          ← Réponses REST
│   │   │   ├── game.models.ts         ← Modèles métier partie
│   │   │   ├── question.models.ts     ← Modèles métier question
│   │   │   ├── quiz.models.ts         ← Modèles métier quiz
│   │   │   └── websocket.models.ts    ← Messages WebSocket
│   │   ├── services/
│   │   │   ├── auth.service.ts        ← Auto-login, token JWT, refresh
│   │   │   ├── websocket.service.ts   ← Connexion WS, reconnexion RxJS
│   │   │   └── game-state.service.ts  ← Signals : état courant de la partie
│   │   ├── interceptors/
│   │   │   └── auth.interceptor.ts    ← Injection Bearer sur toutes les requêtes
│   │   ├── guards/
│   │   │   ├── auth.guard.ts          ← App initialisée ?
│   │   │   ├── active-game.guard.ts   ← Partie active requise (pilotage)
│   │   │   └── no-active-game.guard.ts ← Pas de partie active (contenu)
│   │   └── core.providers.ts          ← APP_INITIALIZER, provideHttpClient, etc.
│   │
│   ├── shared/                        ← Composants réutilisables
│   │   ├── confirm-dialog/
│   │   │   └── confirm-dialog.component.ts
│   │   ├── paginator/
│   │   │   └── paginator.component.ts
│   │   ├── status-badge/
│   │   │   └── status-badge.component.ts
│   │   └── timer/
│   │       └── timer.component.ts
│   │
│   ├── dashboard/
│   │   └── dashboard.component.ts
│   │
│   ├── content/
│   │   ├── content-shell.component.ts
│   │   ├── themes/
│   │   │   ├── theme-list.component.ts
│   │   │   └── theme.service.ts
│   │   ├── questions/
│   │   │   ├── question-list.component.ts
│   │   │   ├── question-form.component.ts
│   │   │   └── question.service.ts
│   │   ├── quizzes/
│   │   │   ├── quiz-list.component.ts
│   │   │   ├── quiz-form.component.ts
│   │   │   └── quiz.service.ts
│   │   └── sounds/
│   │       ├── sound-list.component.ts
│   │       └── sound.service.ts
│   │
│   ├── games/
│   │   ├── game-list.component.ts
│   │   ├── game-create.component.ts
│   │   ├── game-results.component.ts
│   │   └── game.service.ts
│   │
│   ├── pilot/
│   │   ├── pilot-shell.component.ts
│   │   ├── lobby/
│   │   │   └── lobby.component.ts
│   │   ├── play/
│   │   │   ├── play.component.ts
│   │   │   ├── mcq-control/
│   │   │   │   └── mcq-control.component.ts
│   │   │   ├── speed-control/
│   │   │   │   └── speed-control.component.ts
│   │   │   ├── player-list/
│   │   │   │   └── player-list.component.ts
│   │   │   ├── ranking/
│   │   │   │   └── ranking.component.ts
│   │   │   └── sound-panel/
│   │   │       └── sound-panel.component.ts
│   │   └── results/                   ← Alias vers game-results
│   │
│   ├── error/
│   │   └── error.component.ts
│   │
│   ├── app.routes.ts
│   ├── app.config.ts
│   └── app.component.ts
│
└── environments/
    ├── environment.ts
    └── environment.prod.ts
```

---

## 🏷️ Modèles TypeScript — `websocket.models.ts`

```typescript
export type GameStatus =
  | 'PENDING' | 'OPEN'
  | 'QUESTION_TITLE' | 'QUESTION_OPEN'
  | 'QUESTION_BUZZED' | 'QUESTION_CLOSED'
  | 'COMPLETED' | 'IN_ERROR';

export type QuestionType = 'MCQ' | 'SPEED';

// ── Messages Angular → Serveur ──────────────────────────────────────────────
export type OutboundMessage =
  | { type: 'auth';                    token: string }
  | { type: 'trigger_title' }
  | { type: 'trigger_choices' }
  | { type: 'trigger_correction' }
  | { type: 'trigger_next_question' }
  | { type: 'validate_answer' }
  | { type: 'invalidate_answer' }
  | { type: 'trigger_intermediate_ranking' }
  | { type: 'trigger_system_sound';    sound_id: SystemSoundId; targets?: string[] }
  | { type: 'play_sound';              sound_id: string;        targets?: string[] }
  | { type: 'auth_refresh';            token: string }
  | { type: 'request_game_state' };

export type SystemSoundId =
  | 'BUZZ_PRESSED' | 'BUZZ_LOCKED' | 'BUZZ_INVALIDATED'
  | 'CORRECT_ANSWER' | 'WRONG_ANSWER' | 'TIMER_END'
  | 'GAME_START' | 'GAME_END' | 'WAITING' | 'SUSPENSE';

// ── Types partagés ────────────────────────────────────────────────────────────
export interface ParticipantState {
  order: number;
  name: string;
  cumulative_score: number;
}

export interface RankingEntry {
  rank: number;
  participant_name: string;
  participant_order: number;
  cumulative_score: number;
  total_time_ms: number;
}
```

---

## 🎮 `GameStateService` — structure des Signals

```typescript
interface GameState {
  gameId:           string | null;
  status:           GameStatus | null;
  quizId:           string | null;
  questionIndex:    number | null;
  questionType:     QuestionType | null;
  questionTitle:    string | null;
  choices:          [string, string, string, string] | null;
  participants:     ParticipantState[];
  connectedBuzzers: string[];
  startedAt:        string | null;
  timeLimit:        number | null;
  remainingSeconds: number | null;
  playerAnswers:    PlayerAnswer[];
  allAnswered:      boolean;
  timerEnded:       boolean;
  currentBuzzer:    BuzzerState | null;
  lastSummaryMcq:   QuestionResultSummaryMcq | null;
  lastSummarySpeed: QuestionResultSummarySpeed | null;
  ranking:          RankingEntry[] | null;
}

// Signals exposés (lecture seule)
readonly state            = this._state.asReadonly();
readonly status           = computed(() => this._state().status);
readonly isActive         = computed(() => { ... });
readonly isPiloting       = computed(() => this.isActive() || this.status() === 'PENDING');
readonly canCorrect       = computed(() => {
  const s = this._state();
  return s.status === 'QUESTION_OPEN' && (s.allAnswered || s.timerEnded);
});
readonly connectedBuzzers = computed(() => this._state().connectedBuzzers);

// Polling pour mises à jour des buzzers en temps réel
requestSync(): void { this.ws.send({ type: 'request_game_state' }); }
startPolling(intervalMs = 3_000): void { ... }  // Envoie request_game_state périodiquement
stopPolling(): void { ... }                       // Arrête le polling
```

> **Polling buzzers** : Le serveur n'envoie pas d'événements `buzzer_connected` individuels aux clients admin.
> Le lobby (3 s) et le dashboard (5 s) appellent `startPolling()` / `stopPolling()` pour recevoir
> des `game_state_sync` rafraîchis contenant la liste `connected_buzzers` à jour.

---

## 🔀 Routing complet — `app.routes.ts`

```typescript
export const routes: Routes = [
  { path: '', redirectTo: 'dashboard', pathMatch: 'full' },
  {
    path: 'dashboard',
    canActivate: [authGuard],
    loadComponent: () => import('./dashboard/dashboard.component')
  },
  {
    path: 'content',
    canActivate: [authGuard, noActiveGameGuard],
    loadComponent: () => import('./content/content-shell.component'),
    children: [
      { path: '',              redirectTo: 'questions', pathMatch: 'full' },
      { path: 'themes',        loadComponent: () => import('./content/themes/theme-list.component') },
      { path: 'questions',     loadComponent: () => import('./content/questions/question-list.component') },
      { path: 'questions/new', loadComponent: () => import('./content/questions/question-form.component') },
      { path: 'questions/:id', loadComponent: () => import('./content/questions/question-form.component') },
      { path: 'quizzes',       loadComponent: () => import('./content/quizzes/quiz-list.component') },
      { path: 'quizzes/new',   loadComponent: () => import('./content/quizzes/quiz-form.component') },
      { path: 'quizzes/:id',   loadComponent: () => import('./content/quizzes/quiz-form.component') },
      { path: 'sounds',        loadComponent: () => import('./content/sounds/sound-list.component') },
    ]
  },
  {
    path: 'games',
    canActivate: [authGuard],
    children: [
      { path: '',           loadComponent: () => import('./games/game-list.component') },
      { path: ':id/results', loadComponent: () => import('./games/game-results.component') },
    ]
  },
  {
    path: 'pilot',
    canActivate: [authGuard, activeGameGuard],
    loadComponent: () => import('./pilot/pilot-shell.component'),
    children: [
      { path: '',        redirectTo: 'lobby', pathMatch: 'full' },
      { path: 'lobby',   loadComponent: () => import('./pilot/lobby/lobby.component') },
      { path: 'play',    loadComponent: () => import('./pilot/play/play.component') },
      { path: 'results', loadComponent: () => import('./games/game-results.component') },
    ]
  },
  { path: 'error', loadComponent: () => import('./error/error.component') },
  { path: '**',    redirectTo: 'dashboard' }
];
```

---

## 🛡️ Guards

```typescript
// auth.guard.ts — App initialisée (auto-login réussi)
export const authGuard: CanActivateFn = () => {
  const auth = inject(AuthService);
  return auth.isReady()
    ? true
    : inject(Router).createUrlTree(['/error']);
};

// active-game.guard.ts — Partie active requise
export const activeGameGuard: CanActivateFn = () => {
  const gs = inject(GameStateService);
  return gs.isPiloting()
    ? true
    : inject(Router).createUrlTree(['/dashboard']);
};

// no-active-game.guard.ts — Pas de partie active (backoffice)
export const noActiveGameGuard: CanActivateFn = () => {
  const gs = inject(GameStateService);
  if (!gs.isPiloting()) return true;
  inject(Router).navigate(['/pilot/play']);
  return false;
};
```

---

## ⚙️ Configuration — `app.config.ts`

```typescript
export const appConfig: ApplicationConfig = {
  providers: [
    provideRouter(routes, withComponentInputBinding()),
    provideHttpClient(withInterceptors([authInterceptor])),
    provideAnimations(),
    {
      provide: APP_INITIALIZER,
      useFactory: (auth: AuthService, ws: WebSocketService, gs: GameStateService) =>
        async () => {
          await auth.initialize();   // POST /api/v1/token
          ws.connect();              // Connexion WebSocket + auth
          await gs.syncInitial();    // GET /api/v1/games (partie active ?)
        },
      deps: [AuthService, WebSocketService, GameStateService],
      multi: true
    }
  ]
};
```

---

## 🔄 Flux d'initialisation complet

```
APP_INITIALIZER
  ├── AuthService.initialize()
  │     └── POST /api/v1/token → token stocké dans signal
  │           → Échec : navigate('/error') — bloquant
  ├── WebSocketService.connect()
  │     └── new WebSocket(wsUrl)
  │           → send { type: 'auth', token }
  │           → reçoit auth_success
  │           → reçoit game_state_sync (si partie active)
  │                 → GameStateService.dispatch() → signal mis à jour
  └── GameStateService.syncInitial()
        └── GET /api/v1/games
              → si partie active : état local initialisé
              → Router décide la vue initiale depuis dashboard
```

---

## 🎮 Contrat `PlayComponent` ↔ sous-composants

`PlayComponent` orchestre l'affichage conditionnel selon `GameStateService.status()` :

```typescript
// play.component.ts (squelette)
@Component({ template: `
  @if (gs.status() === 'QUESTION_TITLE' || gs.status() === 'QUESTION_OPEN'
       || gs.status() === 'QUESTION_CLOSED') {
    @if (gs.state().questionType === 'MCQ') {
      <app-mcq-control />
    } @else {
      <app-speed-control />
    }
  }
  @if (gs.state().ranking) {
    <app-ranking />           <!-- overlay, par-dessus tout -->
  }
  <app-player-list />         <!-- colonne gauche, toujours visible -->
  <app-sound-panel />         <!-- colonne droite, toujours visible -->
`})
export class PlayComponent {
  readonly gs = inject(GameStateService);
  readonly ws = inject(WebSocketService);
}
```

Les sous-composants **ne lisent que des signals computed** et **n'injectent pas `WebSocketService` directement**. Ils émettent des actions via `Output()` que `PlayComponent` traite. Le seul endroit qui appelle `ws.send()` dans l'espace pilotage est `PlayComponent`.

---

**Dernière mise à jour** : 2026-03-28
