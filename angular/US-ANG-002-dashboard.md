# US-ANG-002 — Tableau de bord

## 📋 Contexte projet

Voir [VISION.md](VISION.md) pour la description complète du projet et de ses quatre applications.

---

## 🎯 User Story

> **En tant que** maître de jeu,
> **je veux** voir en un coup d'œil l'état du système dès l'ouverture de l'application,
> **afin de** savoir immédiatement si une partie est en cours, combien de buzzers sont connectés, et accéder rapidement à n'importe quelle section.

---

## ✅ Critères d'acceptance

> 🧪 **Exigence de couverture** — Voir [CONVENTIONS-TECHNIQUES-ANGULAR.md](CONVENTIONS-TECHNIQUES-ANGULAR.md). Couverture `DashboardComponent` ≥ 70 %. Couverture `GameService` ≥ 80 %.

### Chargement initial des données

| # | Critère | Résultat attendu |
|---|---|---|
| CA-1 | Au chargement du composant, `GET /api/v1/games?page=1&limit=4` est appelé pour charger les 4 dernières parties | Tri serveur par date décroissante — les 4 premières entrées de la réponse sont affichées |
| CA-2 | `GET /api/v1/quizzes` et `GET /api/v1/questions?limit=1` sont appelés en parallèle pour obtenir les compteurs | Appel simultané via `forkJoin` — aucun appel n'attend l'autre |
| CA-3 | Les 4 métriques affichées sont : buzzers connectés, nombre de quiz, nombre de questions, nombre de parties jouées | Buzzers : depuis `GameStateService.connectedBuzzers()` (signal, temps réel) — les trois autres : depuis les réponses REST |
| CA-4 | Pendant le chargement, un état de chargement est affiché à la place des métriques et de la liste | Indicateur visuel — pas de skeleton élaboré (KISS) |
| CA-5 | En cas d'erreur sur un appel REST, les métriques concernées affichent `—` sans bloquer le reste de l'affichage | Chaque appel gère son erreur indépendamment |

### Bannière de partie active

| # | Critère | Résultat attendu |
|---|---|---|
| CA-6 | Si `GameStateService.isPiloting()` est `true`, la bannière bleue de partie active est affichée avec le nom du quiz, le statut et la progression (`question_index / total`) | `GameStateService.state()` fournit `gameId`, `status`, `questionIndex`, `quizId` |
| CA-7 | Si `GameStateService.isPiloting()` est `false`, la bannière est absente | Aucun élément résiduel dans le DOM |
| CA-8 | Le bouton "Reprendre le pilotage" de la bannière navigue vers `/pilot/lobby` si `status === 'PENDING'`, vers `/pilot/play` si `status` est `OPEN` ou un état `QUESTION_*` | Routage conditionnel sur le signal `GameStateService.status()` |
| CA-9 | La bannière se met à jour en temps réel si une partie est créée ou démarrée depuis un autre onglet | `GameStateService` est mis à jour par `game_state_sync` via WebSocket — le composant réagit via `computed` |

### Compteur de buzzers en temps réel

| # | Critère | Résultat attendu |
|---|---|---|
| CA-10 | La métrique "Buzzers connectés" reflète `GameStateService.connectedBuzzers().length` | Mise à jour instantanée sur tout changement du signal — pas de polling |
| CA-11 | Le sous-titre de la métrique liste les usernames des buzzers connectés, séparés par une virgule, tronqués à 3 noms si plus de 3 | Au-delà : `alice, bob, charlie +2` |
| CA-12 | La liste des buzzers connectés dans la carte dédiée se met à jour en temps réel | Même source : `GameStateService.connectedBuzzers()` |

### Liste des dernières parties

| # | Critère | Résultat attendu |
|---|---|---|
| CA-13 | La liste affiche les 4 dernières parties avec nom de la partie (quiz name), statut, date formatée | Statut rendu par `StatusBadgeComponent` avec couleur appropriée par statut |
| CA-14 | Un clic sur "Voir" redirige vers `/games/:id/results` si la partie est `COMPLETED` | Navigation Angular Router |
| CA-15 | Un clic sur "Voir" redirige vers `/pilot/play` si la partie est `OPEN` ou un état `QUESTION_*` | Navigation Angular Router |
| CA-16 | Un clic sur "Voir" redirige vers `/pilot/lobby` si la partie est `PENDING` | Navigation Angular Router |

### Bouton "Nouvelle partie"

| # | Critère | Résultat attendu |
|---|---|---|
| CA-17 | Le bouton "Nouvelle partie" est visible en permanence dans l'en-tête de la page | Toujours présent |
| CA-18 | Si `GameStateService.isPiloting()` est `true`, un clic sur "Nouvelle partie" affiche un toast d'avertissement "Une partie est déjà en cours" et ne navigue pas | Aucune navigation — le toast disparaît après 4 secondes |
| CA-19 | Si `GameStateService.isPiloting()` est `false`, un clic navigue vers `/games/new` | Navigation Angular Router |

### Navigation latérale

| # | Critère | Résultat attendu |
|---|---|---|
| CA-20 | La sidebar affiche les liens vers Tableau de bord, Thèmes, Questions, Quiz, Jingles, Toutes les parties | Lien actif mis en évidence selon la route courante |
| CA-21 | Les liens du groupe Contenu (Thèmes, Questions, Quiz, Jingles) sont visuellement désactivés et non cliquables si `GameStateService.isPiloting()` est `true` | Style `opacity: 0.4; pointer-events: none` — un tooltip explique "Indisponible pendant une partie" |
| CA-22 | Si une tentative de navigation directe vers une route `/content/*` est effectuée alors qu'une partie est active, `noActiveGameGuard` redirige vers `/pilot/play` | Le guard est évalué par le Router, pas par la sidebar |

### Statut de connexion serveur

| # | Critère | Résultat attendu |
|---|---|---|
| CA-23 | La topbar affiche l'adresse du serveur et un indicateur vert "Connecté" si le WebSocket est établi | État lu depuis `WebSocketService.isConnected()` (signal) |
| CA-24 | L'indicateur passe à orange "Reconnexion…" si le WebSocket est en cours de reconnexion | État lu depuis `WebSocketService.isReconnecting()` (signal) |
| CA-25 | `GET /api/v1/health` est appelé une fois au chargement du composant, sans auth | Affichage discret de la version du serveur dans le footer de la topbar si disponible |

---

## 🔧 Spécifications techniques

Voir [CONVENTIONS-TECHNIQUES-ANGULAR.md](CONVENTIONS-TECHNIQUES-ANGULAR.md) pour la stack complète, les principes et les conventions de code.

### `DashboardComponent` — interface et chargement

```typescript
@Component({
  selector: 'app-dashboard',
  standalone: true,
  changeDetection: ChangeDetectionStrategy.OnPush,
  imports: [StatusBadgeComponent, PaginatorComponent, /* ... */]
})
export class DashboardComponent {
  private readonly gameService  = inject(GameService);
  private readonly quizService  = inject(QuizService);
  protected readonly gs         = inject(GameStateService);
  private readonly router       = inject(Router);

  // Métriques REST
  protected readonly recentGames   = signal<Game[]>([]);
  protected readonly quizCount     = signal<number | null>(null);
  protected readonly questionCount = signal<number | null>(null);
  protected readonly isLoading     = signal(true);

  // Computed depuis GameStateService
  protected readonly activeBannerRoute = computed(() => {
    const s = this.gs.status();
    if (!s || s === 'COMPLETED' || s === 'IN_ERROR') return null;
    return s === 'PENDING' ? '/pilot/lobby' : '/pilot/play';
  });

  constructor() {
    this.loadDashboardData();
  }

  private loadDashboardData(): void {
    forkJoin({
      games:     this.gameService.getRecent(4),
      quizCount: this.quizService.getCount(),
    })
    .pipe(takeUntilDestroyed())
    .subscribe({
      next: ({ games, quizCount }) => {
        this.recentGames.set(games);
        this.quizCount.set(quizCount);
        this.isLoading.set(false);
      },
      error: () => this.isLoading.set(false)
    });
  }

  protected onNewGameClick(): void {
    if (this.gs.isPiloting()) {
      // afficher toast
      return;
    }
    this.router.navigate(['/games/new']);
  }

  protected gameDetailRoute(game: Game): string {
    const s = game.status;
    if (s === 'COMPLETED' || s === 'IN_ERROR') return `/games/${game.id}/results`;
    if (s === 'PENDING') return '/pilot/lobby';
    return '/pilot/play';
  }
}
```

### `GameService` — méthodes utilisées par ce composant

```typescript
// Retourne les N parties les plus récentes (tri serveur, page 1)
getRecent(limit: number): Observable<Game[]>;

// Retourne uniquement le total depuis la réponse paginée (limit=1)
getCount(): Observable<number>;
```

### `WebSocketService` — signals supplémentaires requis

```typescript
// Ajoutés pour l'indicateur de connexion dans la topbar
readonly isConnected    = signal(false);
readonly isReconnecting = signal(false);
// Mis à jour dans buildStream() : true à auth_success, false sur erreur/fermeture
```

### Appels REST au chargement

| Appel | Endpoint | Justification |
|---|---|---|
| Dernières parties | `GET /api/v1/games?page=1&limit=4` | 4 lignes dans le widget "Dernières parties" |
| Nombre de quiz | `GET /api/v1/quizzes?page=1&limit=1` → `total` | Métrique dashboard |
| Nombre de questions | `GET /api/v1/questions?page=1&limit=1` → `total` | Métrique dashboard |
| Health check | `GET /api/v1/health` | Version serveur — sans Bearer |

### Format de date affiché

```typescript
// Formatage des dates dans la liste des parties
// Aujourd'hui : "Auj. HH:mm"
// Hier : "Hier HH:mm"
// Autre : "DD MMM" (ex. : "26 mars")
// Basé sur Intl.DateTimeFormat — pas de dépendance externe (YAGNI)
```

### `StatusBadgeComponent` — mapping des statuts

| Statut | Couleur | Libellé |
|---|---|---|
| `PENDING` | Ambre | En attente |
| `OPEN` | Bleu | En cours |
| `QUESTION_TITLE` / `QUESTION_OPEN` / `QUESTION_BUZZED` / `QUESTION_CLOSED` | Bleu | En cours |
| `COMPLETED` | Vert | Terminée |
| `IN_ERROR` | Rouge | Erreur |

---

## 📐 Périmètre

| Inclus | Exclu |
|---|---|
| Chargement des 4 dernières parties et affichage | Pagination de la liste complète (→ US-ANG-006) |
| Métriques quiz, questions, parties, buzzers | Graphiques ou visualisations avancées (YAGNI) |
| Bannière de partie active avec lien contextuel | Détail de la question en cours sur le dashboard |
| Mise à jour temps réel des buzzers via Signals | Abonnement à d'autres messages WebSocket (→ US-ANG-008/009) |
| Indicateur de connexion WebSocket | Health check détaillé (YAGNI) |
| Navigation contextuelle "Nouvelle partie" | Gestion d'erreur REST avec retry automatique (YAGNI) |
| Désactivation visuelle des liens Contenu si partie active | Blocage router (`noActiveGameGuard` — déjà dans US-ANG-001) |
| Tests unitaires et d'intégration (couverture ≥ 70 %) | Déploiement / CI-CD |

---

## 🔍 Points de vigilance

### `forkJoin` et gestion partielle des erreurs

`forkJoin` annule tous les observables si l'un d'eux échoue. Pour afficher les données disponibles même en cas d'erreur partielle, chaque observable doit être protégé par `catchError(() => of(null))` avant d'entrer dans le `forkJoin`. Le composant affiche `—` pour les métriques dont la valeur est `null`.

### Buzzers connectés — source unique de vérité

Le compteur de buzzers ne doit **jamais** être lu depuis la réponse REST `GET /api/v1/games`. Il est exclusivement alimenté par `GameStateService.connectedBuzzers()`, lui-même mis à jour par les messages `auth_success` WebSocket (buzzer connecté) et les événements de déconnexion. Cette distinction est critique : la réponse REST représente l'état persisté, pas l'état temps réel des connexions.

### Bannière et `game_state_sync`

La bannière réagit à `GameStateService.isPiloting()` qui est un `computed` dérivé de `GameStateService.status()`. Ce signal est mis à jour lors de chaque `game_state_sync` reçu via WebSocket. Il n'est pas nécessaire d'écouter les événements WebSocket dans `DashboardComponent` — la réactivité est assurée par la chaîne Signal → `computed` → template `@if`.

### Accès sans auth à `GET /api/v1/health`

`GET /api/v1/health` est un endpoint public qui ne nécessite pas de Bearer token. L'`authInterceptor` n'injecte le header que si `AuthService.getToken()` retourne une valeur non-null — le health check, appelé sans token explicite, recevra quand même le header si le token est disponible. Ce comportement est acceptable : le serveur ignore le header sur cet endpoint.

---

## 🔗 Documents liés

| Document | Contenu |
|---|---|
| [VISION.md](VISION.md) | Description complète du projet |
| [CONVENTIONS-TECHNIQUES-ANGULAR.md](CONVENTIONS-TECHNIQUES-ANGULAR.md) | Stack, principes, conventions de code |
| [US-ANG-001 — Initialisation](US-ANG-001-init-session.md) | `AuthService`, `WebSocketService`, `GameStateService` |
| [US-010 — CRUD des parties (serveur)](US-010-game-crud.md) | Format `GET /api/v1/games` |
| [US-020 — Health check (serveur)](US-020-health-check.md) | Format `GET /api/v1/health` |

---

**Dernière mise à jour** : 2026-03-28
**Statut** : Implémentée — tous les critères d'acceptance couverts par des tests (Sprint 1)
**Sprint** : 1
