# US-ANG-008 — Pilotage en direct : questions MCQ, SPEED, classement et résultats

## 📋 Contexte projet

Voir [VISION.md](VISION.md) pour la description complète du projet et de ses quatre applications.

---

## 🎯 User Story

> **En tant que** maître de jeu,
> **je veux** piloter le déroulement de chaque question (MCQ et SPEED), afficher le classement intermédiaire à la demande et consulter les résultats finaux,
> **afin d'** animer la partie en temps réel de la première question jusqu'à la fin.

---

## ✅ Critères d'acceptance

> 🧪 **Exigence de couverture** — Voir [CONVENTIONS-TECHNIQUES-ANGULAR.md](CONVENTIONS-TECHNIQUES-ANGULAR.md). Couverture `GameStateService` (dispatch complet) ≥ 90 %. Couverture `PlayComponent`, `McqControlComponent`, `SpeedControlComponent` ≥ 70 %.

---

### Orchestration — `PlayComponent`

| # | Critère | Résultat attendu |
|---|---|---|
| CA-1 | `PlayComponent` est affiché dès que `GameStateService.status()` est `OPEN`, `QUESTION_TITLE`, `QUESTION_OPEN`, `QUESTION_BUZZED` ou `QUESTION_CLOSED` | `activeGameGuard` garantit l'accès |
| CA-2 | `PlayComponent` monte `McqControlComponent` si `questionType === 'MCQ'`, `SpeedControlComponent` si `questionType === 'SPEED'` | Routage conditionnel via `@if` sur `GameStateService.state().questionType` |
| CA-3 | `RankingComponent` (overlay) est monté si `GameStateService.state().ranking !== null` | Superposé par-dessus l'écran courant sans changer l'état |
| CA-4 | `PlayerListComponent` et `SoundPanelComponent` sont toujours montés pendant le pilotage | Colonnes latérales permanentes |
| CA-5 | En état `OPEN` (entre deux questions), un bouton "Déclencher la question" est actif | `trigger_title` envoyé au clic |
| CA-6 | Si `GameStateService.status()` passe à `COMPLETED`, navigation vers `/pilot/results` | Via `effect()` sur le signal |
| CA-7 | Si `GameStateService.status()` passe à `IN_ERROR`, un banner d'erreur bloquant est affiché | Pas de navigation — le maître peut consulter les résultats partiels |

---

### Workflow MCQ — `McqControlComponent`

#### État `QUESTION_TITLE`

| # | Critère | Résultat attendu |
|---|---|---|
| CA-8 | À la réception de `question_title`, le titre, le numéro de question et le `time_limit` sont affichés | `GameStateService.dispatch()` a mis à jour le signal |
| CA-9 | Un bouton "Afficher les choix" envoie `{ type: 'trigger_choices' }` | Désactivé après clic jusqu'à la réception de `question_choices` |
| CA-10 | Le bouton "Afficher les choix" est désactivé après clic jusqu'à la réception de `question_choices` | Idempotence via signal `isWaiting` local |

#### État `QUESTION_OPEN` (MCQ)

| # | Critère | Résultat attendu |
|---|---|---|
| CA-11 | À la réception de `question_choices`, les 4 choix A/B/C/D sont affichés, le chronomètre démarre | Chrono calculé localement depuis `started_at` — resynchronisé sur `timer_tick` |
| CA-12 | `PlayerListComponent` affiche en temps réel les réponses reçues (`player_answered`) | Chaque entrée : nom, choix sélectionné, temps de réponse |
| CA-13 | Le compteur de réponses reçues est affiché sous forme `N / total` | Mis à jour à chaque `player_answered` |
| CA-14 | À la réception de `all_answered` : bouton "Corriger" activé | `GameStateService.canCorrect()` passe à `true` |
| CA-15 | À la réception de `timer_end` : chrono figé à 0, bouton "Corriger" activé | `GameStateService.canCorrect()` passe à `true` |
| CA-16 | Un clic sur "Corriger" (quand `canCorrect()` est `true`) envoie `{ type: 'trigger_correction' }` | Bouton désactivé immédiatement après envoi |
| CA-17 | Si le serveur retourne `error { code: 'ANSWERS_PENDING' }` : toast d'erreur "Des joueurs n'ont pas encore répondu" | Le bouton reste désactivé |

#### État `QUESTION_CLOSED` (MCQ)

| # | Critère | Résultat attendu |
|---|---|---|
| CA-18 | À la réception de `question_result_summary` : la bonne réponse est mise en évidence (vert), les mauvaises grisées | Conforme au champ `correct_answer` du message |
| CA-19 | Les résultats par participant sont affichés dans `PlayerListComponent` : nom, réponse, temps, points gagnés | Issu de `results[]` dans `question_result_summary` |
| CA-20 | Les scores cumulés sont mis à jour dans la colonne droite | Issu de `ranking[]` dans `question_result_summary` |
| CA-21 | Un bouton "Question suivante" envoie `{ type: 'trigger_next_question' }` | Désactivé immédiatement après envoi |
| CA-22 | Si c'est la dernière question, `game_state_sync { status: 'COMPLETED' }` → navigation vers `/pilot/results` | Via `effect()` dans `PlayComponent` |

---

### Workflow SPEED — `SpeedControlComponent`

#### État `QUESTION_OPEN` (SPEED)

| # | Critère | Résultat attendu |
|---|---|---|
| CA-23 | À la réception de `question_open` : titre affiché, chrono démarré immédiatement depuis `started_at` | `GameStateService.dispatch()` détecte `question_type: 'SPEED'` et monte `SpeedControlComponent` |
| CA-24 | Les boutons "Valider" et "Invalider" sont désactivés en état `QUESTION_OPEN` | Aucune action disponible avant un buzz |
| CA-25 | À la réception de `timer_end` en `QUESTION_OPEN` : chrono figé à 0, aucune action requise côté Angular | Le serveur clôt automatiquement — Angular reçoit `question_result_summary` directement |

#### État `QUESTION_BUZZED`

| # | Critère | Résultat attendu |
|---|---|---|
| CA-26 | À la réception de `buzz_locked` : nom du buzzeur affiché en évidence, chrono suspendu, boutons "Valider" et "Invalider" activés | `GameStateService.dispatch()` met à jour `currentBuzzer` et passe à `QUESTION_BUZZED` |
| CA-27 | `PlayerListComponent` marque le buzzeur comme "Buzzé" et les autres comme "Bloqué" | Basé sur `currentBuzzer` et `connectedBuzzers` |
| CA-28 | Un clic sur "Valider" envoie `{ type: 'validate_answer' }` | Les deux boutons désactivés immédiatement |
| CA-29 | Un clic sur "Invalider" envoie `{ type: 'invalidate_answer' }` | Les deux boutons désactivés immédiatement |
| CA-30 | À la réception de `buzz_unlocked` : chrono reprend depuis `remaining_seconds`, boutons désactivés, joueurs non invalidés repassent en "Prêt" | `currentBuzzer` remis à `null`, statut → `QUESTION_OPEN` |
| CA-31 | À la réception de `timer_end` en `QUESTION_BUZZED` : hint "Temps écoulé — décidez maintenant", boutons toujours actifs | Le serveur attend la décision — Angular n'envoie rien automatiquement |

#### État `QUESTION_CLOSED` (SPEED)

| # | Critère | Résultat attendu |
|---|---|---|
| CA-32 | À la réception de `question_result_summary` (SPEED) : affichage du gagnant (ou "Aucun gagnant") et des points attribués | `winner` issu de `question_result_summary` — `null` si aucun gagnant |
| CA-33 | Les scores cumulés sont mis à jour | Issu de `ranking[]` dans `question_result_summary` |
| CA-34 | Comportement de "Question suivante" identique à MCQ (CA-21 et CA-22) | Même implémentation dans `PlayComponent` |

---

### Classement intermédiaire — `RankingComponent`

| # | Critère | Résultat attendu |
|---|---|---|
| CA-35 | Le bouton "Classement" est disponible dans tous les états actifs | Présent dans `SoundPanelComponent` (colonne droite) |
| CA-36 | Un clic envoie `{ type: 'trigger_intermediate_ranking' }` | Via `Output()` → `PlayComponent` → `ws.send()` |
| CA-37 | À la réception de `intermediate_ranking` : `GameStateService.state().ranking` est mis à jour, `RankingComponent` monté en overlay | Le workflow en cours n'est pas interrompu |
| CA-38 | L'overlay affiche rang, nom, score cumulé et temps cumulé pour chaque participant | Données issues de `GameStateService.state().ranking` |
| CA-39 | La fermeture de l'overlay appelle `GameStateService.dismissRanking()` | Signal `ranking` remis à `null` — overlay démonté |
| CA-40 | Si le serveur retourne `error { code: 'INVALID_STATE' }` : toast discret "Classement indisponible dans cet état" | Pas d'overlay affiché |

---

### Résultats finaux — `GameResultsComponent`

| # | Critère | Résultat attendu |
|---|---|---|
| CA-41 | Accessible depuis `/pilot/results` (fin de partie directe) et `/games/:id/results` (historique) | Même composant — source de données différente selon le contexte |
| CA-42 | En fin de partie directe : données issues des `question_result_summary` accumulés dans `GameStateService` | Pas d'appel REST si la session était active |
| CA-43 | En consultation historique (`/games/:id/results`) : `GET /api/v1/games/:id/results` est appelé | Données issues de la base de données serveur |
| CA-44 | Le podium affiche les 3 premiers avec rang, nom, score final et temps cumulé | Médailles or / argent / bronze |
| CA-45 | Le tableau de détail affiche une ligne par question et une colonne par participant | Cellule verte si correct/gagnant SPEED, rouge si incorrect, grise si absent |
| CA-46 | Les questions SPEED sans gagnant affichent des tirets pour tous les participants | Conforme à l'asymétrie MCQ/SPEED — `answers: []` |
| CA-47 | Le bouton "Nouvelle partie" navigue vers `/games/new` si aucune partie active | |

---

### Reconnexion WebSocket pendant le pilotage

| # | Critère | Résultat attendu |
|---|---|---|
| CA-48 | Si le WebSocket se reconnecte, `game_state_sync` est reçu avec le statut courant | `GameStateService.dispatch()` restaure l'état |
| CA-49 | Si `game_state_sync` contient `started_at` et `time_limit`, le chrono est recalculé | `remaining = time_limit - (Date.now() - new Date(started_at)) / 1000` |
| CA-50 | Après restauration, l'affichage correspond exactement à l'état courant | L'orchestration de `PlayComponent` est pilotée par les signals — le rendu est automatiquement cohérent |

---

## 🔧 Spécifications techniques

Voir [CONVENTIONS-TECHNIQUES-ANGULAR.md](CONVENTIONS-TECHNIQUES-ANGULAR.md) pour la stack complète, les principes et les conventions de code.

### Architecture des composants de pilotage

```
PlayComponent                          ← orchestrateur, seul à appeler ws.send()
  ├── McqControlComponent              ← émetteur via @Output()
  ├── SpeedControlComponent            ← émetteur via @Output()
  ├── PlayerListComponent              ← lecture seule (signals)
  ├── SoundPanelComponent              ← émetteur via @Output()
  └── RankingComponent (overlay)       ← émetteur via @Output() pour la fermeture
```

**Contrat strict** : aucun sous-composant n'injecte `WebSocketService` directement. Toutes les actions remontent via `@Output()` vers `PlayComponent` qui appelle `ws.send()`.

### `PlayComponent` — squelette

```typescript
@Component({ template: `
  <app-player-list />

  @if (gs.status() === 'QUESTION_TITLE' || gs.status() === 'QUESTION_OPEN'
       || gs.status() === 'QUESTION_CLOSED' || gs.status() === 'QUESTION_BUZZED') {
    @if (gs.state().questionType === 'MCQ') {
      <app-mcq-control
        (triggerChoices)="ws.send({ type: 'trigger_choices' })"
        (triggerCorrection)="ws.send({ type: 'trigger_correction' })"
        (triggerNext)="ws.send({ type: 'trigger_next_question' })" />
    } @else {
      <app-speed-control
        (validateAnswer)="ws.send({ type: 'validate_answer' })"
        (invalidateAnswer)="ws.send({ type: 'invalidate_answer' })"
        (triggerNext)="ws.send({ type: 'trigger_next_question' })" />
    }
  }

  @if (gs.status() === 'OPEN') {
    <button (click)="ws.send({ type: 'trigger_title' })">Déclencher la question</button>
  }

  <app-sound-panel
    (triggerSystemSound)="ws.send($event)"
    (playSound)="ws.send($event)"
    (triggerRanking)="ws.send({ type: 'trigger_intermediate_ranking' })" />

  @if (gs.state().ranking) {
    <app-ranking (close)="gs.dismissRanking()" />
  }
` })
export class PlayComponent {
  protected readonly gs = inject(GameStateService);
  protected readonly ws = inject(WebSocketService);

  constructor() {
    effect(() => {
      if (this.gs.status() === 'COMPLETED') {
        inject(Router).navigate(['/pilot/results']);
      }
    }, { injector: inject(Injector) });
  }
}
```

### Chronomètre local — calcul et resynchronisation

```typescript
startTimer(startedAt: string, timeLimit: number): void {
  const elapsed = (Date.now() - new Date(startedAt).getTime()) / 1000;
  this.remainingSeconds.set(Math.max(0, timeLimit - elapsed));
  this.timerInterval = setInterval(() => {
    this.remainingSeconds.update(r => Math.max(0, r - 1));
  }, 1000);
}

onTimerTick(remaining: number): void {
  this.remainingSeconds.set(remaining);  // correction de la dérive locale
}

stopTimer(): void {
  if (this.timerInterval) {
    clearInterval(this.timerInterval);
    this.timerInterval = null;
  }
}
```

### `GameResultsComponent` — deux sources de données

```typescript
ngOnInit(): void {
  const id = this.route.snapshot.paramMap.get('id');
  if (!id) {
    // Fin de partie directe : données depuis GameStateService
    this.results.set(this.gs.buildResults());
  } else {
    // Consultation historique : données depuis le serveur REST
    this.gameService.getResults(id)
      .pipe(takeUntilDestroyed(this.destroyRef))
      .subscribe(r => this.results.set(r));
  }
}
```

### Messages WebSocket envoyés

| Message | Déclencheur |
|---|---|
| `trigger_title` | Bouton "Déclencher la question" (état `OPEN`) |
| `trigger_choices` | Bouton "Afficher les choix" (état `QUESTION_TITLE`, MCQ) |
| `trigger_correction` | Bouton "Corriger" (état `QUESTION_OPEN`, MCQ, `canCorrect()` true) |
| `trigger_next_question` | Bouton "Question suivante" (état `QUESTION_CLOSED`) |
| `validate_answer` | Bouton "Valider" (état `QUESTION_BUZZED`, SPEED) |
| `invalidate_answer` | Bouton "Invalider" (état `QUESTION_BUZZED`, SPEED) |
| `trigger_intermediate_ranking` | Bouton "Classement" (tous états actifs) |

### Messages WebSocket traités par `GameStateService.dispatch()`

| Message reçu | Mise à jour du signal |
|---|---|
| `question_title` | `status → QUESTION_TITLE`, `questionTitle`, `questionType: MCQ`, `timeLimit` |
| `question_choices` | `status → QUESTION_OPEN`, `choices`, `startedAt` |
| `question_open` | `status → QUESTION_OPEN`, `questionType: SPEED`, `questionTitle`, `startedAt`, `timeLimit` |
| `timer_tick` | `remainingSeconds` |
| `timer_end` | `timerEnded: true`, `remainingSeconds: 0` |
| `player_answered` | `playerAnswers` (ajout), `allAnswered` si tous ont répondu |
| `all_answered` | `allAnswered: true` |
| `buzz_locked` | `status → QUESTION_BUZZED`, `currentBuzzer` |
| `buzz_unlocked` | `status → QUESTION_OPEN`, `currentBuzzer: null`, `remainingSeconds` restauré |
| `question_result_summary` | `status → QUESTION_CLOSED`, `lastSummaryMcq` ou `lastSummarySpeed`, scores mis à jour |
| `intermediate_ranking` | `ranking` (signal) |
| `game_state_sync { status: COMPLETED }` | `status → COMPLETED` → navigation via `effect()` |

### Endpoint consommé

| Appel | Endpoint | US serveur | Contexte |
|---|---|---|---|
| Résultats finaux (historique) | `GET /api/v1/games/:id/results` | US-013 | `GameResultsComponent` depuis `/games/:id/results` |

---

## 📐 Périmètre

| Inclus | Exclu |
|---|---|
| Workflow MCQ complet (4 états, chrono local) | Affichage des médias image/audio des questions sur l'écran Angular (YAGNI) |
| Workflow SPEED complet (buzz, invalidation multiple, chrono suspendu) | Édition des questions en cours de partie |
| Classement intermédiaire en overlay non bloquant | Historique des classements intermédiaires |
| Résultats finaux (fin de partie directe ET consultation historique) | Export des résultats (YAGNI) |
| Reconnexion WebSocket transparente avec restauration de l'état et du chrono | |
| Gestion `IN_ERROR` avec banner bloquant | |
| Tests unitaires et d'intégration (couverture ≥ 70 %) | Déploiement / CI-CD |

---

## 🔍 Points de vigilance

### `trigger_title` — asymétrie MCQ vs SPEED

Angular envoie toujours `{ type: 'trigger_title' }` sans connaître le type de la question suivante. La réponse est soit `question_title` (MCQ) soit `question_open` (SPEED). `GameStateService.dispatch()` détecte le type depuis le message reçu et met à jour `questionType`. `PlayComponent` monte alors le bon sous-composant.

### Chrono local — source de dérive

Le chrono Angular décrémente localement toutes les secondes. `timer_tick` (toutes les 5 s côté serveur) corrige la dérive en réaffectant `remainingSeconds` directement. La décision d'expiration appartient toujours au serveur (`timer_end`).

### Idempotence des boutons d'action

Chaque bouton est désactivé immédiatement après le clic via un signal `isWaiting`. Il ne se réactive qu'à la réception du prochain message WebSocket attendu — évite les doubles envois.

### `GameResults` depuis `GameStateService` vs REST

En fin de partie directe, `buildResults()` reconstruit le résultat depuis les `question_result_summary` accumulés. Si Angular s'est reconnecté en cours de partie et a manqué des messages, fallback sur `GET /api/v1/games/:id/results` — source de vérité absolue.

---

## 🔗 Documents liés

| Document | Contenu |
|---|---|
| [VISION.md](VISION.md) | Description complète du projet |
| [CONVENTIONS-TECHNIQUES-ANGULAR.md](CONVENTIONS-TECHNIQUES-ANGULAR.md) | Stack, principes, conventions |
| [US-ANG-001 — Initialisation](US-ANG-001-init-session.md) | `GameStateService`, `WebSocketService` |
| [US-ANG-007 — Lobby](US-ANG-007-lobby.md) | Flux précédent |
| [US-011 — Workflow MCQ (serveur)](US-011-mcq-question-workflow.md) | Protocole WebSocket MCQ complet |
| [US-012 — Workflow SPEED (serveur)](US-012-speed-question-workflow.md) | Protocole WebSocket SPEED complet |
| [US-013 — Résultats finaux (serveur)](US-013-game-results.md) | Endpoint `GET /api/v1/games/:id/results` |
| [US-014 — Classement intermédiaire (serveur)](US-014-intermediate-ranking-display.md) | Message `trigger_intermediate_ranking` |

---

**Dernière mise à jour** : 2026-03-28
**Statut** : Rédigée — en attente d'implémentation (Sprints 6 et 7)
**Sprint** : 6 (MCQ + classement + résultats), 7 (SPEED)
