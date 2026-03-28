# PLAN-IMPLEMENTATION-ANGULAR.md

## 📋 Principes de planification

Trois contraintes gouvernent l'ordre :

**Dépendances techniques** — un composant ne peut pas être développé avant le service dont il dépend. `GameStateService` doit exister avant tout composant de pilotage.

**Dépendances serveur** — Angular consomme des endpoints qui doivent être implémentés côté serveur. L'ordre supposé ici est que le serveur Node.js est entièrement terminé.

**Valeur livrable** — chaque sprint produit quelque chose de testable end-to-end, pas uniquement des briques isolées.

---

## 🗺️ Carte des dépendances

```
environment.ts
    │
    ├── AuthService ──────────────────────── APP_INITIALIZER
    │       │
    │       ├── authInterceptor
    │       └── WebSocketService ──────────── GameStateService
    │                                               │
    │                         ┌─────────────────────┼──────────────────────┐
    │                         │                     │                      │
    │                    authGuard          activeGameGuard        noActiveGameGuard
    │                         │                     │                      │
    │                    (toutes              PilotShellComponent    ContentShellComponent
    │                    les routes)          LobbyComponent         ThemeListComponent
    │                                         PlayComponent          QuestionListComponent
    │                                         McqControlComponent    QuestionFormComponent
    │                                         SpeedControlComponent  QuizListComponent
    │                                         PlayerListComponent    QuizFormComponent
    │                                         RankingComponent       SoundListComponent
    │                                         SoundPanelComponent
    │
    ├── GameService (REST) ─────────────── GameListComponent
    │                                      GameCreateComponent
    │                                      GameResultsComponent
    │
    ├── QuestionService (REST) ─────────── QuestionListComponent
    │                                      QuestionFormComponent
    │
    ├── QuizService (REST) ─────────────── QuizListComponent
    │                                      QuizFormComponent
    │
    ├── ThemeService (REST) ────────────── ThemeListComponent
    │                                      QuestionFormComponent (select thème)
    │
    └── SoundService (REST) ────────────── SoundListComponent
                                           SoundPanelComponent (pilotage)
```

---

## 📅 Plan par sprints

### Sprint 0 — Fondations (pas de livrable UI)

**Objectif** : tout ce qui doit exister avant de pouvoir afficher quoi que ce soit.

| # | Tâche | Fichiers produits |
|---|---|---|
| 0.1 | Initialisation du projet Angular 18 | `angular.json`, `tsconfig.json`, `package.json` |
| 0.2 | Configuration ESLint + Prettier | `.eslintrc.json`, `.prettierrc` |
| 0.3 | Configuration Jest | `jest.config.ts`, `setup-jest.ts` |
| 0.4 | `environment.ts` / `environment.prod.ts` | Variables serveur, WS, credentials |
| 0.5 | Modèles TypeScript complets | `core/models/*.ts` |
| 0.6 | `AuthService` + test | `auth.service.ts`, `auth.service.spec.ts` |
| 0.7 | `WebSocketService` + test | `websocket.service.ts`, `websocket.service.spec.ts` |
| 0.8 | `GameStateService` (dispatch + signals) + test | `game-state.service.ts`, `*.spec.ts` |
| 0.9 | `authInterceptor` + test | `auth.interceptor.ts`, `*.spec.ts` |
| 0.10 | Guards (`auth`, `active-game`, `no-active-game`) + tests | `*.guard.ts`, `*.spec.ts` |
| 0.11 | `app.config.ts` avec `APP_INITIALIZER` | `app.config.ts` |
| 0.12 | Routing complet (routes déclarées, lazy load) | `app.routes.ts` |
| 0.13 | `AppComponent` (shell vide) | `app.component.ts` |
| 0.14 | `ErrorComponent` | `error.component.ts` |
| 0.15 | Composants partagés (`ConfirmDialog`, `Paginator`, `StatusBadge`, `Timer`) | `shared/*.ts` |

**Critère de sortie** : `ng serve` démarre, l'auto-login s'exécute, la connexion WebSocket s'établit, le routing fonctionne même si toutes les routes pointent vers des composants vides.

---

### Sprint 1 — Tableau de bord

**Dépendances** : Sprint 0 complet, `GameService` (liste des parties).

| # | Tâche | US couverte |
|---|---|---|
| 1.1 | `GameService.getActive()` + `getRecent()` | — |
| 1.2 | Navigation latérale (sidebar partagée) | — |
| 1.3 | `DashboardComponent` complet | US-ANG-001, US-ANG-002 |

**Critère de sortie** : le dashboard s'affiche avec les métriques réelles, la bannière apparaît si une partie est active, les buzzers connectés se mettent à jour en temps réel.

---

### Sprint 2 — Gestion des thèmes et questions

**Objectif** : premier pan du backoffice, les questions étant le contenu de base de tout le reste.

**Dépendances** : Sprint 1, `ThemeService`, `QuestionService`.

| # | Tâche | US couverte |
|---|---|---|
| 2.1 | `ThemeService` CRUD + tests | — |
| 2.2 | `ContentShellComponent` (layout avec nav latérale) | — |
| 2.3 | `ThemeListComponent` | UC-THEME-01 à 04 |
| 2.4 | `QuestionService` (liste, filtres, CRUD, upload média) + tests | — |
| 2.5 | `QuestionListComponent` avec filtres | US-ANG-003 (partiel) |
| 2.6 | `QuestionFormComponent` — mode création MCQ | US-ANG-003 (partiel) |
| 2.7 | `QuestionFormComponent` — mode création SPEED | US-ANG-003 (partiel) |
| 2.8 | `QuestionFormComponent` — mode édition + upload médias | US-ANG-003 (complet) |

**Critère de sortie** : le maître de jeu peut créer, lister, filtrer, modifier et supprimer des thèmes et des questions, avec upload de médias.

---

### Sprint 3 — Gestion des quiz

**Dépendances** : Sprint 2 (`QuestionService` et `ThemeService` disponibles pour les filtres du compositeur).

| # | Tâche | US couverte |
|---|---|---|
| 3.1 | `QuizService` CRUD + tests | — |
| 3.2 | `QuizListComponent` (cards avec `question_summary`) | US-ANG-004 |
| 3.3 | `QuizFormComponent` — banque de questions + filtres | US-ANG-005 (partiel) |
| 3.4 | `QuizFormComponent` — composition ordonnée + drag-and-drop | US-ANG-005 (complet) |

**Point d'attention** : le drag-and-drop via `@angular/cdk/drag-drop` doit être importé dans `QuizFormComponent`. L'ordre du tableau local est la source de vérité envoyée dans `question_ids`.

**Critère de sortie** : le maître de jeu peut créer un quiz en sélectionnant et réordonnant des questions, avec validation du minimum de 10 questions.

---

### Sprint 4 — Gestion des jingles et liste des parties

**Dépendances** : Sprint 1 (dashboard), Sprint 2 et 3 (contenu).

| # | Tâche | US couverte |
|---|---|---|
| 4.1 | `SoundService` (upload, liste, suppression) + tests | — |
| 4.2 | `SoundListComponent` | UC-SOUND-01 à 03 |
| 4.3 | `GameService` (CRUD complet) + tests | — |
| 4.4 | `GameListComponent` (liste avec statuts, badges) | US-ANG-006 |
| 4.5 | `GameCreateComponent` (formulaire + aperçu quiz) | US-ANG-007 |
| 4.6 | `GameResultsComponent` (consultation depuis liste) | US-ANG-011 (partiel) |

**Critère de sortie** : tout le backoffice est fonctionnel end-to-end — thèmes, questions, quiz, jingles, parties.

---

### Sprint 5 — Lobby et démarrage de partie

**Dépendances** : Sprint 4 (`GameService` complet), `GameStateService` (buzzers connectés via WebSocket).

| # | Tâche | US couverte |
|---|---|---|
| 5.1 | `PilotShellComponent` (layout avec `router-outlet`) | — | ✅ |
| 5.2 | `LobbyComponent` (buzzers en temps réel, readiness bar) | US-ANG-007 | ✅ |
| 5.3 | Navigation automatique `PENDING → /pilot/lobby` à la création | US-ANG-007 (fin) | ✅ |
| 5.4 | Navigation automatique `OPEN → /pilot/play` au démarrage | US-ANG-007 (fin) | ✅ |
| 5.5 | `GameStateService.reset()` pour annulation de partie | US-ANG-007 | ✅ |

**Critère de sortie** : le maître de jeu peut créer une partie, voir les buzzers se connecter en temps réel dans le lobby, démarrer la partie et être redirigé automatiquement vers le pilotage.

---

### Sprint 6 — Pilotage MCQ

**Dépendances** : Sprint 5, `GameStateService` complet avec dispatch de tous les messages MCQ.

**Ordre interne imposé** : les composants feuilles avant l'orchestrateur.

| # | Tâche | US couverte |
|---|---|---|
| 6.1 | `PlayerListComponent` (réponses en temps réel) | US-ANG-008 (partiel) | ✅ |
| 6.2 | `SoundPanelComponent` (sons système + jingles + classement) | US-ANG-008 (CA-35/36) | ✅ |
| 6.3 | `RankingComponent` (overlay classement intermédiaire) | US-ANG-008 (CA-35 à 40) | ✅ |
| 6.4 | `McqControlComponent` (titre → choix → correction) | US-ANG-008 (CA-8 à 22) | ✅ |
| 6.5 | `PlayComponent` — orchestration MCQ complète | US-ANG-008 (CA-1 à 7) | ✅ |
| 6.6 | `GameResultsComponent` — fin de partie (`/pilot/results`) | US-ANG-008 (CA-41 à 47) | ✅ |

**Critère de sortie** : une question MCQ peut être pilotée de bout en bout — déclenchement du titre, affichage des choix, réception des réponses en temps réel, correction, passage à la question suivante, fin de partie avec résultats.

---

### Sprint 7 — Pilotage SPEED

**Dépendances** : Sprint 6 (`PlayComponent`, `PlayerListComponent`, `SoundPanelComponent`, `RankingComponent` déjà disponibles).

| # | Tâche | US couverte |
|---|---|---|
| 7.1 | Compléter `GameStateService` dispatch SPEED (`buzz_locked`, `buzz_unlocked`) | US-ANG-008 (CA-26 à 31) | ✅ |
| 7.2 | `SpeedControlComponent` (attente buzz → décision) | US-ANG-008 (CA-23 à 34) | ✅ |
| 7.3 | Routing conditionnel MCQ/SPEED dans `PlayComponent` | US-ANG-008 (CA-2) | ✅ |

**Point d'attention** : `PlayComponent` doit déjà exister depuis le sprint 6. La tâche 7.3 est une modification, pas une création — elle consiste à ajouter le branchement `@if (questionType === 'SPEED')` et à monter `SpeedControlComponent` à la place de `McqControlComponent`.

**Critère de sortie** : une question SPEED peut être pilotée — buzz reçu, chrono suspendu, carte buzzeur affichée, validation ou invalidation avec reprise du chrono, cycle d'invalidation multiple, fin de question.

---

### Sprint 8 — Reconnexion et robustesse

**Dépendances** : Sprints 5–7 (tous les états de la machine à états couverts).

| # | Tâche | US couverte |
|---|---|---|
| 8.1 | Gestion `token_expiring_soon` → refresh silencieux dans `AuthService` | US-ANG-001 (CA-12 à CA-16) |
| 8.2 | Gestion `game_state_sync` à la reconnexion WebSocket | UC-PILOT-12 |
| 8.3 | Restauration de l'état chrono (`started_at` + `time_limit`) après reconnexion | UC-PILOT-12 |
| 8.4 | `NoActiveGameGuard` — redirection avec toast informatif | — |
| 8.5 | Gestion `IN_ERROR` — affichage message d'erreur dans pilotage | — |
| 8.6 | Tests d'intégration end-to-end (flux complet MCQ et SPEED mockés) | — |

**Critère de sortie** : la perte et reprise de connexion WebSocket ne brise pas l'état de l'application. Le token se renouvelle silencieusement. Un état `IN_ERROR` est géré gracieusement.

---

## 📊 Vue synthétique

```
Sprint 0 │████████████████████│ Fondations (services, guards, routing)
Sprint 1 │████                │ Tableau de bord
Sprint 2 │████████████        │ Thèmes + Questions
Sprint 3 │████████            │ Quiz
Sprint 4 │████████            │ Jingles + Liste des parties
Sprint 5 │████                │ Lobby + démarrage
Sprint 6 │████████████        │ Pilotage MCQ complet
Sprint 7 │████                │ Pilotage SPEED
Sprint 8 │████████            │ Reconnexion + robustesse
```

---

## 🔗 Dépendances inter-sprints critiques

| Dépendance | Raison |
|---|---|
| Sprint 0 doit être **entièrement** terminé avant tout autre | `GameStateService` et les guards sont des prérequis universels |
| `ThemeService` (Sprint 2) avant `QuestionFormComponent` | Le formulaire charge les thèmes pour son select |
| `QuestionService` (Sprint 2) avant `QuizFormComponent` (Sprint 3) | Le compositeur charge la banque de questions |
| `GameService` (Sprint 4) avant `LobbyComponent` (Sprint 5) | Le lobby crée et supprime des parties via REST |
| `McqControlComponent` (Sprint 6) avant `SpeedControlComponent` (Sprint 7) | `PlayComponent` doit exister pour y brancher SPEED |
| Sprint 6 entier avant Sprint 8 | On ne peut pas tester la reconnexion sans que les états soient tous gérés |

---

## ⚠️ Points de vigilance à l'implémentation

**`GameStateService.dispatch()` est le cœur du système.** Toute régression ici casse le pilotage entier. Les tests de ce service doivent couvrir 100 % des branches de `switch`, un message à la fois. Ne jamais tester plusieurs transitions dans un seul `it()`.

**Le chrono SPEED après reconnexion** est le cas le plus délicat. À la réception de `game_state_sync` avec `status: QUESTION_OPEN` et `started_at` + `time_limit`, Angular doit calculer `remaining = time_limit - (Date.now() - new Date(started_at).getTime()) / 1000`. Ce calcul doit être encapsulé dans une fonction pure testable indépendamment du composant.

**Le guard `noActiveGameGuard`** doit lire `GameStateService.isPiloting()` qui est un `computed`. Au moment où le guard s'exécute lors de l'initialisation, le signal peut ne pas encore être à jour si `APP_INITIALIZER` n'est pas encore terminé — c'est pourquoi `APP_INITIALIZER` doit être **bloquant** (`async`) et terminer avant que le Router ne commence à résoudre les routes.

**`QuizFormComponent` et le drag-and-drop** : l'ordre du tableau `selectedQuestionIds` est la source de vérité unique. Ne jamais dériver l'ordre depuis le DOM — toujours depuis le signal.

---

**Dernière mise à jour** : 2026-03-28
