# US-ANG-006 — Liste des parties et création

## 📋 Contexte projet

Voir [VISION.md](VISION.md) pour la description complète du projet et de ses quatre applications.

---

## 🎯 User Story

> **En tant que** maître de jeu,
> **je veux** consulter l'historique de mes parties, créer une nouvelle partie en choisissant un quiz et des participants, et y accéder directement,
> **afin de** gérer le cycle de vie complet de mes sessions de jeu.

---

## ✅ Critères d'acceptance

> 🧪 **Exigence de couverture** — Voir [CONVENTIONS-TECHNIQUES-ANGULAR.md](CONVENTIONS-TECHNIQUES-ANGULAR.md). Couverture `GameService` ≥ 80 %. Couverture `GameListComponent` et `GameCreateComponent` ≥ 70 %.

---

### Liste des parties — `GameListComponent`

#### Chargement initial

| # | Critère | Résultat attendu |
|---|---|---|
| CA-1 | Au chargement, `GET /api/v1/games?page=1&limit=20` est appelé | Liste triée par date de création décroissante |
| CA-2 | Chaque ligne affiche : nom du quiz associé, statut (via `StatusBadgeComponent`), date de création formatée, nombre de participants | Le nom du quiz est résolu localement depuis un index `quiz_id → quiz_name` |
| CA-3 | `PaginatorComponent` affiche la navigation entre les pages | Conforme à `{ page, total_pages }` de la réponse serveur |

> **Note sur CA-2** : `GET /api/v1/games` retourne `quiz_id` mais pas `quiz_name`. Angular charge les noms des quiz en parallèle via `GET /api/v1/quizzes?limit=100` au chargement, puis fait correspondre `quiz_id → quiz_name` localement via une `Map`.

#### Navigation contextuelle

| # | Critère | Résultat attendu |
|---|---|---|
| CA-4 | Un clic sur "Voir" d'une partie `COMPLETED` ou `IN_ERROR` navigue vers `/games/:id/results` | Accès aux résultats finaux |
| CA-5 | Un clic sur "Voir" d'une partie `PENDING` navigue vers `/pilot/lobby` | Reprise du lobby |
| CA-6 | Un clic sur "Voir" d'une partie `OPEN` ou `QUESTION_*` navigue vers `/pilot/play` | Reprise du pilotage en cours |

#### Suppression

| # | Critère | Résultat attendu |
|---|---|---|
| CA-7 | Le bouton "Supprimer" est visible uniquement sur les parties en statut `PENDING` | Les parties `OPEN`, `COMPLETED` ou `IN_ERROR` n'ont pas de bouton de suppression |
| CA-8 | Un clic sur "Supprimer" ouvre `ConfirmDialogComponent` avec le nom du quiz associé | La confirmation est requise avant tout appel réseau |
| CA-9 | Après confirmation, `DELETE /api/v1/games/:id` est appelé | En cas de `204` : la liste est rechargée avec toast "Partie supprimée" |

#### Bouton "Nouvelle partie"

| # | Critère | Résultat attendu |
|---|---|---|
| CA-10 | Le bouton "Nouvelle partie" est affiché en en-tête | Toujours visible |
| CA-11 | Si `GameStateService.isPiloting()` est `true`, un clic affiche un toast "Une partie est déjà en cours" et ne navigue pas | Pas de navigation |
| CA-12 | Sinon, un clic navigue vers `/games/new` | Navigation Angular Router |

---

### Formulaire de création — `GameCreateComponent`

#### Chargement initial

| # | Critère | Résultat attendu |
|---|---|---|
| CA-13 | Au chargement de `/games/new`, `GET /api/v1/quizzes?limit=100` est appelé pour peupler le select de quiz | Liste triée par date décroissante — pas de pagination dans ce contexte |
| CA-14 | Si `GameStateService.isPiloting()` est `true` au chargement, redirection vers `/pilot/play` avec toast d'avertissement | Sécurité défensive — le guard devrait déjà empêcher l'accès |

#### Sélection du quiz

| # | Critère | Résultat attendu |
|---|---|---|
| CA-15 | Le select de quiz affiche le nom de chaque quiz | Option par défaut "— Sélectionner un quiz —" désactivée |
| CA-16 | À la sélection d'un quiz, `GET /api/v1/quizzes/:id` est appelé pour afficher l'aperçu | Aperçu : nombre de questions, répartition MCQ/SPEED, niveaux min–max |
| CA-17 | Si aucun quiz n'est disponible (liste vide), un message "Aucun quiz disponible — créez d'abord un quiz" est affiché avec un lien vers `/content/quizzes/new` | Pas d'option vide dans le select |

#### Saisie des participants

| # | Critère | Résultat attendu |
|---|---|---|
| CA-18 | Le formulaire démarre avec un participant vide, le bouton "+ Ajouter" est disponible jusqu'à 10 participants | Minimum 1 participant au moment de la soumission |
| CA-19 | Chaque champ de nom de participant est validé : non vide, ≤ 50 caractères | Message d'erreur inline sous le champ en erreur |
| CA-20 | Les noms de participants doivent être uniques au sein de la liste (comparaison locale insensible à la casse) | Message d'erreur inline "Ce nom est déjà utilisé" |
| CA-21 | Le bouton de suppression `×` retire un participant — désactivé si un seul participant est présent | Au minimum 1 participant requis |
| CA-22 | Le compteur `N / 10` s'affiche à côté du libellé "Participants" | Calculé depuis `participants().length` |

#### Soumission

| # | Critère | Résultat attendu |
|---|---|---|
| CA-23 | Le bouton "Créer la partie" est désactivé si aucun quiz n'est sélectionné ou si la liste de participants est invalide | Désactivation via `computed` — aucun appel réseau possible dans cet état |
| CA-24 | Un clic sur "Créer la partie" appelle `POST /api/v1/games` avec `{ quiz_id, participants: [nom1, nom2, ...] }` | Les participants sont envoyés sous forme de tableau de chaînes, dans l'ordre d'ajout |
| CA-25 | En cas de `201` : `GameStateService.initFromGame()` est appelé, navigation vers `/pilot/lobby` | La partie est immédiatement considérée comme active |
| CA-26 | En cas de `409 ACTIVE_GAME_EXISTS` : toast d'erreur "Une partie est déjà en cours" avec lien "Reprendre la partie" | Pas de navigation |
| CA-27 | En cas de `404 QUIZ_NOT_FOUND` : toast d'erreur "Le quiz sélectionné n'existe plus" | Rechargement de la liste des quiz |
| CA-28 | En cas d'erreur réseau ou `5xx` : toast d'erreur générique | Pas de navigation |

---

## 🔧 Spécifications techniques

Voir [CONVENTIONS-TECHNIQUES-ANGULAR.md](CONVENTIONS-TECHNIQUES-ANGULAR.md) pour la stack complète, les principes et les conventions de code.

### `GameService` — interface publique complète

```typescript
@Injectable({ providedIn: 'root' })
export class GameService {
  getAll(params?: { page?: number; limit?: number }): Observable<PagedResponse<Game>>;
  getById(id: string): Observable<Game>;
  getActive(): Observable<Game | null>;
  getRecent(limit: number): Observable<Game[]>;
  getCount(): Observable<number>;
  getResults(id: string): Observable<GameResults>;
  create(dto: CreateGameDto): Promise<Game>;
  start(id: string): Promise<Game>;
  delete(id: string): Promise<void>;
}
```

### `GameCreateComponent` — state local

```typescript
protected readonly quizzes           = signal<QuizSummary[]>([]);
protected readonly selectedQuizId    = signal<string | null>(null);
protected readonly quizPreview       = signal<QuizDetail | null>(null);
protected readonly isLoadingPreview  = signal(false);
protected readonly participants      = signal<string[]>(['']);
protected readonly fieldErrors       = signal<Record<string, string>>({});
protected readonly isSubmitting      = signal(false);
protected readonly isValid = computed(() =>
  this.selectedQuizId() !== null &&
  this.participants().length >= 1 &&
  this.participants().every(p => p.trim().length > 0 && p.trim().length <= 50) &&
  new Set(this.participants().map(p => p.trim().toLowerCase())).size === this.participants().length
);
```

### Mise à jour de `GameStateService` après création

```typescript
// Dans GameStateService
initFromGame(game: Game): void {
  this._state.update(() => ({
    ...INITIAL_STATE,
    gameId:       game.id,
    status:       'PENDING',
    quizId:       game.quiz_id,
    participants: game.participants.map(p => ({
      order:            p.order,
      name:             p.name,
      cumulative_score: 0
    }))
  }));
}
```

### Enrichissement des noms de quiz dans `GameListComponent`

```typescript
forkJoin({
  games:   this.gameService.getAll({ page: 1, limit: 20 }),
  quizzes: this.quizService.getAll({ limit: 100 })
})
.pipe(takeUntilDestroyed())
.subscribe(({ games, quizzes }) => {
  const quizNameMap = new Map(quizzes.data.map(q => [q.id, q.name]));
  this.games.set(games.data.map(g => ({
    ...g,
    quizName: quizNameMap.get(g.quiz_id) ?? g.quiz_id
  })));
  this.totalPages.set(games.total_pages);
});
```

### Endpoints consommés

| Appel | Endpoint | US serveur | Contexte |
|---|---|---|---|
| Liste des parties | `GET /api/v1/games` | US-010 | `GameListComponent` |
| Liste des quiz (enrichissement) | `GET /api/v1/quizzes?limit=100` | US-008 | `GameListComponent` |
| Liste des quiz (select création) | `GET /api/v1/quizzes?limit=100` | US-008 | `GameCreateComponent` |
| Quiz par ID (aperçu) | `GET /api/v1/quizzes/:id` | US-008 | `GameCreateComponent` |
| Création de partie | `POST /api/v1/games` | US-010 | `GameCreateComponent` |
| Suppression de partie | `DELETE /api/v1/games/:id` | US-010 | `GameListComponent` |

---

## 📐 Périmètre

| Inclus | Exclu |
|---|---|
| Liste paginée des parties avec statuts | Filtrage de la liste par statut (YAGNI) |
| Navigation contextuelle selon le statut de la partie | Édition des participants après création (→ US-ANG-007 lobby) |
| Suppression des parties `PENDING` uniquement | Suppression des parties actives ou terminées |
| Aperçu du quiz sélectionné (nb questions, MCQ/SPEED, niveaux) | Validation des questions du quiz avant création (YAGNI) |
| Validation locale des participants (unicité, longueur) | |
| Mise à jour immédiate de `GameStateService` après création | Attente du `game_state_sync` WebSocket pour initialiser l'état |
| Tests unitaires et d'intégration (couverture ≥ 70 %) | Déploiement / CI-CD |

---

## 🔍 Points de vigilance

### Mise à jour de `GameStateService` — REST vs WebSocket

Après la création (`POST` → `201`), Angular met à jour `GameStateService` directement via `initFromGame()` sans attendre `game_state_sync`. Ce choix garantit une navigation immédiate vers le lobby. Si `game_state_sync` arrive ensuite, `dispatch()` le traite normalement — l'état est simplement confirmé.

### Enrichissement du nom de quiz — limite à 100

Si un utilisateur possède plus de 100 quiz (cas extrême), certains noms ne seront pas résolus et l'UUID sera affiché à la place. Ce compromis est acceptable (KISS).

### Unicité des participants — comparaison insensible à la casse

La validation locale utilise `.toLowerCase()` pour être cohérente avec la validation serveur. "Alice" et "alice" sont considérés comme des doublons.

---

## 🔗 Documents liés

| Document | Contenu |
|---|---|
| [VISION.md](VISION.md) | Description complète du projet |
| [CONVENTIONS-TECHNIQUES-ANGULAR.md](CONVENTIONS-TECHNIQUES-ANGULAR.md) | Stack, principes, conventions de code |
| [US-ANG-001 — Initialisation](US-ANG-001-init-session.md) | `GameStateService` |
| [US-ANG-007 — Lobby](US-ANG-007-lobby.md) | Suite immédiate après création |
| [US-010 — CRUD des parties (serveur)](US-010-game-crud.md) | Endpoints POST, GET, DELETE |
| [US-008 — CRUD des quiz (serveur)](US-008-quiz-crud.md) | Endpoint GET pour l'aperçu et l'enrichissement |

---

**Dernière mise à jour** : 2026-03-28
**Statut** : Rédigée — en attente d'implémentation (Sprint 4)
**Sprint** : 4
