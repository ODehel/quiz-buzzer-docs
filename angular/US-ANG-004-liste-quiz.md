# US-ANG-004 — Liste des quiz

## 📋 Contexte projet

Voir [VISION.md](VISION.md) pour la description complète du projet et de ses quatre applications.

---

## 🎯 User Story

> **En tant que** maître de jeu,
> **je veux** lister les quiz existants sous forme de cards avec le résumé des questions par niveau et par type, filtrer par nom, paginer, et supprimer un quiz,
> **afin de** retrouver et gérer rapidement mes quiz avant de créer une partie.

---

## ✅ Critères d'acceptance

> 🧪 **Exigence de couverture** — Voir [CONVENTIONS-TECHNIQUES-ANGULAR.md](CONVENTIONS-TECHNIQUES-ANGULAR.md). Couverture `QuizService` ≥ 80 %. Couverture `QuizListComponent` ≥ 70 %.

---

### Chargement initial

| # | Critère | Résultat attendu |
|---|---|---|
| CA-1 | Au chargement, `GET /api/v1/quizzes?page=1&limit=20` est appelé | La liste des quiz est affichée sous forme de cards |
| CA-2 | Chaque card affiche le nom du quiz et le nombre total de questions (`question_summary.total`) | Informations visibles sans interaction |
| CA-3 | Chaque card affiche le résumé des questions par niveau avec les badges MCQ et SPEED (`question_summary.by_level`) | Les niveaux sans questions ne sont pas affichés |
| CA-4 | Le total de résultats retourné par le serveur (`total`) est affiché en badge à côté du titre | Mis à jour à chaque requête |

### Filtrage par nom

| # | Critère | Résultat attendu |
|---|---|---|
| CA-5 | La saisie dans le champ de recherche déclenche un appel `GET /api/v1/quizzes?name=<valeur>` | Filtrage 100 % côté serveur — recherche insensible à la casse, contient |
| CA-6 | Le bouton "Réinitialiser" remet le filtre à vide et relance `GET /api/v1/quizzes` sans paramètre `name` | Appel sans query param de filtrage |

### Pagination

| # | Critère | Résultat attendu |
|---|---|---|
| CA-7 | `PaginatorComponent` est affiché si `total_pages > 1`, masqué sinon | Conforme à `{ page, total_pages }` de la réponse serveur |

### Actions sur une card

| # | Critère | Résultat attendu |
|---|---|---|
| CA-8 | Le bouton d'édition (crayon) navigue vers `/content/quizzes/:id` | Le formulaire se charge en mode édition |
| CA-9 | Le bouton "Nouveau quiz" navigue vers `/content/quizzes/new` | Le formulaire se charge en mode création |
| CA-10 | Le bouton de suppression (corbeille) ouvre `ConfirmDialogComponent` avec le nom du quiz | La confirmation est requise avant tout appel réseau |
| CA-11 | Après confirmation, `DELETE /api/v1/quizzes/:id` est appelé | En cas de `204` : la liste est rechargée avec toast "Quiz supprimé" |
| CA-12 | En cas de `403 QUIZ_IN_USE` : un message d'erreur explicite "Ce quiz est utilisé par une partie active" est affiché | Pas de rechargement de la liste |

### État vide et erreurs

| # | Critère | Résultat attendu |
|---|---|---|
| CA-13 | Si aucun quiz en base, le message "Aucun quiz" est affiché | Pas de cards, bouton de création toujours visible |
| CA-14 | Chaque card affiche la date de création du quiz | Format : "aujourd'hui", "hier", ou date locale (fr-FR) |
| CA-15 | Si `last_updated_at` est non null, la date de dernière modification est affichée | Si null, seule la date de création est visible |
| CA-16 | Un état de chargement est affiché pendant la récupération des données | Texte "Chargement..." visible |
| CA-17 | Plusieurs quiz sont affichés en grille responsive de cards | Grille `auto-fill` avec `minmax(320px, 1fr)` |
| CA-18 | En cas d'erreur réseau au chargement, un toast d'erreur est affiché | Message "Erreur lors du chargement" |

---

## 🔧 Spécifications techniques

Voir [CONVENTIONS-TECHNIQUES-ANGULAR.md](CONVENTIONS-TECHNIQUES-ANGULAR.md) pour la stack complète, les principes et les conventions de code.

### `QuizService` — interface publique

```typescript
@Injectable({ providedIn: 'root' })
export class QuizService {
  // Liste paginée avec filtre par nom
  getAll(filters: QuizFilters): Observable<PagedResponse<Quiz>>;

  // Quiz par ID (pour édition — US-ANG-005)
  getById(id: string): Observable<QuizDetail>;

  // Compteur (pour dashboard)
  getCount(): Observable<number>;

  // Création
  create(dto: CreateQuizDto): Promise<QuizCreateResponse>;

  // Modification complète
  update(id: string, dto: CreateQuizDto): Promise<QuizCreateResponse>;

  // Suppression
  delete(id: string): Promise<void>;
}
```

### Types — `quiz.models.ts`

```typescript
export interface QuizQuestionSummary {
  total: number;
  by_level: Record<string, Record<QuestionType, number>>;
}

export interface Quiz {
  id: string;
  name: string;
  created_at: string;
  last_updated_at: string | null;
  question_summary: QuizQuestionSummary;
}

export interface QuizDetail {
  id: string;
  name: string;
  question_ids: string[];
  created_at: string;
  last_updated_at: string | null;
}

export interface QuizFilters {
  page: number;
  limit: number;
  name?: string;
}

export interface CreateQuizDto {
  name: string;
  question_ids: string[];
}

export interface QuizCreateResponse {
  id: string;
  name: string;
  question_count: number;
  created_at: string;
  last_updated_at: string | null;
}
```

### Endpoints consommés

| Appel | Endpoint | US serveur |
|---|---|---|
| Liste des quiz | `GET /api/v1/quizzes` | US-008 (CA-15 à CA-23) |
| Suppression | `DELETE /api/v1/quizzes/:id` | US-008 (CA-36 à CA-42) |

### Fichiers produits

| Fichier | Rôle |
|---|---|
| `src/app/core/models/quiz.models.ts` | Interfaces TypeScript |
| `src/app/content/quizzes/quiz.service.ts` | Service HTTP CRUD |
| `src/app/content/quizzes/quiz-list.component.ts` | Composant liste des quiz |
| `src/app/content/quizzes/quiz.service.spec.ts` | Tests du service |
| `src/app/content/quizzes/quiz-list.component.spec.ts` | Tests du composant |

---

## 📐 Périmètre

| Inclus | Exclu |
|---|---|
| Liste paginée des quiz sous forme de cards | Formulaire de création / édition (US-ANG-005) |
| Résumé des questions par niveau et type (MCQ / SPEED) | Drag-and-drop de composition (US-ANG-005) |
| Filtre par nom (recherche côté serveur) | Filtres avancés (YAGNI) |
| Suppression avec garde `QUIZ_IN_USE` | Suppression en lot (YAGNI) |
| Route `/content/quizzes` dans `app.routes.ts` | Tri des colonnes (YAGNI) |
| `QuizService` CRUD complet (préparé pour US-ANG-005) | |
| Tests unitaires (couverture ≥ 70 %) | |

---

## 🔍 Points de vigilance

### `question_summary.by_level` — structure dynamique

Le champ `by_level` est un `Record<string, Record<QuestionType, number>>` dont les clés (`"1"` à `"5"`) ne sont présentes que si au moins une question de ce niveau existe dans le quiz. Le template doit itérer sur les 5 niveaux possibles et n'afficher une ligne que si la clé existe dans l'objet.

### Garde de suppression côté serveur

La suppression retourne `403 QUIZ_IN_USE` si le quiz est référencé par une partie active (`PENDING` ou `OPEN`). Angular intercepte ce code spécifique pour afficher un message explicite. Les parties en état `COMPLETED` ne bloquent pas la suppression.

### Route `/content/quizzes` ajoutée dans `app.routes.ts`

La route est ajoutée comme enfant de `content` avec le même guard `noActiveGameGuard`. Le lien dans la sidebar (`nav-quizzes`) pointait déjà vers `/content/quizzes` — cette US lui donne un composant effectif.

---

## 🔗 Documents liés

| Document | Contenu |
|---|---|
| [VISION.md](VISION.md) | Description complète du projet |
| [CONVENTIONS-TECHNIQUES-ANGULAR.md](CONVENTIONS-TECHNIQUES-ANGULAR.md) | Stack, principes, conventions de code |
| [US-ANG-001 — Initialisation](US-ANG-001-init-session.md) | `AuthService`, `WebSocketService` |
| [US-ANG-003 — Gestion des questions](US-ANG-003-gestion-questions.md) | `QuestionService`, `QuestionListComponent` |
| [US-008 — CRUD quiz (serveur)](../hub/US-008-quiz-crud.md) | Endpoints et contrat API |

---

**Dernière mise à jour** : 2026-03-28
**Statut** : Implémentée (Sprint 3)
**Sprint** : 3
