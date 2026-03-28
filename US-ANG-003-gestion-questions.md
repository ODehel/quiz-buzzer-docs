# US-ANG-003 — Gestion des questions

## 📋 Contexte projet

Voir [VISION.md](VISION.md) pour la description complète du projet et de ses quatre applications.

---

## 🎯 User Story

> **En tant que** maître de jeu,
> **je veux** lister, filtrer, créer, modifier et supprimer les questions de la banque, et leur associer des fichiers image ou audio,
> **afin de** constituer et maintenir le contenu de mes quiz.

---

## ✅ Critères d'acceptance

> 🧪 **Exigence de couverture** — Voir [CONVENTIONS-TECHNIQUES-ANGULAR.md](CONVENTIONS-TECHNIQUES-ANGULAR.md). Couverture `QuestionService` ≥ 80 %. Couverture `QuestionListComponent` et `QuestionFormComponent` ≥ 70 %.

---

### Liste et filtrage des questions — `QuestionListComponent`

#### Chargement initial

| # | Critère | Résultat attendu |
|---|---|---|
| CA-1 | Au chargement, `GET /api/v1/questions?page=1&limit=20` et `GET /api/v1/themes` sont appelés en parallèle via `forkJoin` | La liste des questions et la liste des thèmes (pour le filtre) sont disponibles simultanément |
| CA-2 | La liste affiche pour chaque question : titre tronqué, thème, badge de type (MCQ / SPEED), indicateur de niveau (5 points), durée, points, icônes médias | Les icônes image et audio indiquent visuellement la présence d'un fichier (`image_path` ou `audio_path` non null) |
| CA-3 | Le total de résultats retourné par le serveur (`total`) est affiché à côté des filtres | Mis à jour à chaque requête |

#### Filtrage

| # | Critère | Résultat attendu |
|---|---|---|
| CA-4 | Chaque changement de filtre (thème, type, niveau min/max, points min/max) déclenche un nouvel appel `GET /api/v1/questions` avec les paramètres mis à jour | Filtrage 100 % côté serveur — aucun filtre local |
| CA-5 | Les filtres de plage (niveau min/max, points min/max) sont validés avant l'envoi : min ≤ max | Si min > max, le filtre invalide est marqué en rouge et la requête n'est pas émise |
| CA-6 | `level` exact et `level_min`/`level_max` sont mutuellement exclusifs — le composant n'expose qu'un filtre de plage | Conforme à la règle d'exclusivité de l'US-006 serveur — Angular n'envoie jamais `level` et `level_min` simultanément |
| CA-7 | Le bouton "Réinitialiser" remet tous les filtres à leur valeur par défaut et relance `GET /api/v1/questions` sans paramètres de filtre | Appel sans query params de filtrage |

#### Pagination

| # | Critère | Résultat attendu |
|---|---|---|
| CA-8 | `PaginatorComponent` affiche la page courante, le total de pages et les boutons de navigation | Conforme à `{ page, total_pages }` de la réponse serveur |
| CA-9 | Un clic sur un numéro de page appelle `GET /api/v1/questions?page=N&<filtres_actifs>` | Les filtres actifs sont conservés lors du changement de page |

#### Actions sur une ligne

| # | Critère | Résultat attendu |
|---|---|---|
| CA-10 | Le bouton d'édition (crayon) navigue vers `/content/questions/:id` | Le formulaire se charge en mode édition avec les données de la question |
| CA-11 | Le bouton de suppression (corbeille) ouvre `ConfirmDialogComponent` avec le titre de la question | La confirmation est requise avant tout appel réseau |
| CA-12 | Après confirmation, `DELETE /api/v1/questions/:id` est appelé | En cas de `204` : la liste est rechargée ; en cas de `409 QUESTION_IN_QUIZ` : un message d'erreur explicite "Cette question appartient à un ou plusieurs quiz" est affiché sans rechargement |

---

### Formulaire de création / édition — `QuestionFormComponent`

#### Initialisation du formulaire

| # | Critère | Résultat attendu |
|---|---|---|
| CA-13 | En mode création (`/content/questions/new`), `GET /api/v1/themes` est appelé pour peupler le select de thème | Le formulaire est vide avec les valeurs par défaut : type MCQ, niveau 3, durée 30 s, points 200 |
| CA-14 | En mode édition (`/content/questions/:id`), `GET /api/v1/questions/:id` et `GET /api/v1/themes` sont appelés en parallèle | Le formulaire est prérempli avec toutes les valeurs de la question existante |
| CA-15 | En mode édition, si l'ID dans l'URL est inexistant (`404`), le composant navigue vers `/content/questions` avec un toast d'erreur | Pas d'affichage d'un formulaire vide trompeur |

#### Toggle MCQ / SPEED

| # | Critère | Résultat attendu |
|---|---|---|
| CA-16 | En mode création, le toggle MCQ / SPEED est actif et bascule l'affichage de la section "Propositions" | MCQ : 4 champs de choix + sélecteur de bonne réponse — SPEED : 1 champ "Réponse attendue" |
| CA-17 | En mode édition, le toggle est **désactivé** (type immuable côté serveur) | L'indicateur de type est affiché en lecture seule — aucune interaction possible |

#### Validation MCQ

| # | Critère | Résultat attendu |
|---|---|---|
| CA-18 | Les 4 champs de choix sont obligatoires, non vides, maximum 40 caractères chacun | Message d'erreur inline sous le champ en erreur |
| CA-19 | Les 4 choix doivent être distincts (comparaison insensible à la casse) | Message d'erreur inline "Les choix doivent être uniques" dès la saisie |
| CA-20 | La bonne réponse est désignée via une case radio sur la ligne du choix correspondant | Exactement une case cochée — le choix coché doit correspondre à l'un des 4 choix saisis |
| CA-21 | La case radio se déplace automatiquement si la valeur du choix sélectionné est modifiée | La correspondance `correct_answer === choices[i]` est réévaluée à chaque frappe |

#### Validation SPEED

| # | Critère | Résultat attendu |
|---|---|---|
| CA-22 | Le champ "Réponse attendue" est obligatoire, 1–40 caractères | Message d'erreur inline sous le champ |

#### Paramètres (sliders)

| # | Critère | Résultat attendu |
|---|---|---|
| CA-23 | Le slider Niveau couvre 1 à 5, avec affichage temps réel de la valeur et de la représentation visuelle (points colorés) | Valeur par défaut : 3 |
| CA-24 | Le slider Durée couvre 5 à 120 secondes (pas de 5), avec affichage temps réel | Valeur par défaut : 30 s |
| CA-25 | Le slider Points couvre 50 à 500 (pas de 50), avec affichage temps réel | Valeur par défaut : 200 pts |

#### Soumission — création

| # | Critère | Résultat attendu |
|---|---|---|
| CA-26 | Un clic sur "Créer la question" déclenche la validation complète du formulaire avant tout appel réseau | Si invalide : tous les champs en erreur sont mis en évidence — aucun appel HTTP |
| CA-27 | Si valide, `POST /api/v1/questions` est appelé avec le payload complet | En cas de `201` : navigation vers `/content/questions` avec toast "Question créée" |
| CA-28 | En cas de `409 QUESTION_ALREADY_EXISTS` : message d'erreur inline sous le champ titre "Ce titre existe déjà" | Pas de navigation — le formulaire reste ouvert |
| CA-29 | En cas d'erreur réseau ou `5xx` : toast d'erreur générique "Erreur serveur, réessayez" | Pas de navigation |

#### Soumission — édition

| # | Critère | Résultat attendu |
|---|---|---|
| CA-30 | Un clic sur "Enregistrer les modifications" appelle `PATCH /api/v1/questions/:id` avec uniquement les champs modifiés | Conforme à la sémantique JSON Merge Patch de l'US-007 — les champs non modifiés sont absents du body |
| CA-31 | En cas de `200` : navigation vers `/content/questions` avec toast "Question mise à jour" | Si `last_updated_at` inchangé (données identiques), le toast est quand même affiché |
| CA-32 | En cas de `409 QUESTION_ALREADY_EXISTS` : message d'erreur inline sous le champ titre | Même comportement qu'en création |

---

### Upload de médias — intégré dans `QuestionFormComponent`

| # | Critère | Résultat attendu |
|---|---|---|
| CA-33 | En mode **création**, les zones de dépôt image et audio sont affichées mais désactivées | Une infobulle indique "Sauvegardez d'abord la question pour ajouter des médias" — aucun appel réseau possible |
| CA-34 | En mode **édition**, les zones de dépôt sont actives et acceptent des fichiers par glisser-déposer ou par clic | Ouverture du sélecteur de fichiers natif au clic |
| CA-35 | Avant d'envoyer le fichier, une validation locale vérifie la taille (≤ 10 Mo) et le type MIME attendu | Si invalide : message d'erreur inline "Fichier trop volumineux (max 10 Mo)" ou "Type non accepté" — aucun appel réseau |
| CA-36 | Si les validations locales passent, `POST /api/v1/questions/:id/media` est appelé avec `multipart/form-data` contenant `type` et `file` | En cas de `200` : les champs `image_path` / `audio_path` du signal local sont mis à jour — aperçu affiché |
| CA-37 | Si une image ou un audio est déjà présent, un bouton de suppression est disponible sur l'aperçu | Un clic ouvre `ConfirmDialogComponent` |
| CA-38 | Après confirmation, `DELETE /api/v1/questions/:id/media/image` ou `DELETE /api/v1/questions/:id/media/audio` est appelé | En cas de `204` : l'aperçu disparaît, la zone de dépôt réapparaît |
| CA-39 | Le chemin retourné par le serveur (`image_path` / `audio_path`) est préfixé par `environment.serverUrl` pour construire l'URL absolue de prévisualisation | `http://192.168.1.10:3000/uploads/questions/<uuid>-image.jpg` |

---

## 🔧 Spécifications techniques

Voir [CONVENTIONS-TECHNIQUES-ANGULAR.md](CONVENTIONS-TECHNIQUES-ANGULAR.md) pour la stack complète, les principes et les conventions de code.

### `QuestionService` — interface publique

```typescript
@Injectable({ providedIn: 'root' })
export class QuestionService {
  // Liste paginée avec filtres
  getAll(filters: QuestionFilters): Observable<PagedResponse<Question>>;

  // Question par ID
  getById(id: string): Observable<Question>;

  // Création
  create(dto: CreateQuestionDto): Promise<Question>;

  // Modification partielle (JSON Merge Patch)
  patch(id: string, changes: Partial<PatchQuestionDto>): Promise<Question>;

  // Suppression
  delete(id: string): Promise<void>;

  // Upload de média
  uploadMedia(id: string, type: 'image' | 'audio', file: File): Promise<MediaUploadResponse>;

  // Suppression de média
  deleteMedia(id: string, type: 'image' | 'audio'): Promise<void>;
}
```

### `QuestionFormComponent` — state local (Signals)

```typescript
// Mode
protected readonly mode       = signal<'create' | 'edit'>('create');
protected readonly questionId = signal<string | null>(null);

// Données du formulaire
protected readonly formType          = signal<QuestionType>('MCQ');
protected readonly formThemeId       = signal<string>('');
protected readonly formTitle         = signal<string>('');
protected readonly formChoices       = signal<[string,string,string,string]>(['','','','']);
protected readonly formCorrectAnswer = signal<string>('');
protected readonly formLevel         = signal<number>(3);
protected readonly formTimeLimit     = signal<number>(30);
protected readonly formPoints        = signal<number>(200);

// Médias (lecture seule — mis à jour par les endpoints)
protected readonly imagePath  = signal<string | null>(null);
protected readonly audioPath  = signal<string | null>(null);

// État UI
protected readonly isSubmitting  = signal(false);
protected readonly isUploading   = signal<'image' | 'audio' | null>(null);
protected readonly fieldErrors   = signal<Record<string, string>>({});
```

### Calcul du payload PATCH (édition uniquement)

```typescript
// Comparaison avec l'état initial pour n'envoyer que les champs modifiés
private buildPatchPayload(original: Question): Partial<PatchQuestionDto> {
  const patch: Partial<PatchQuestionDto> = {};
  if (this.formTitle()         !== original.title)          patch.title = this.formTitle();
  if (this.formThemeId()       !== original.theme_id)       patch.theme_id = this.formThemeId();
  if (this.formLevel()         !== original.level)          patch.level = this.formLevel();
  if (this.formTimeLimit()     !== original.time_limit)     patch.time_limit = this.formTimeLimit();
  if (this.formPoints()        !== original.points)         patch.points = this.formPoints();
  if (this.formCorrectAnswer() !== original.correct_answer) patch.correct_answer = this.formCorrectAnswer();
  if (this.formType() === 'MCQ') {
    const choicesChanged = this.formChoices().some((c, i) => c !== original.choices?.[i]);
    if (choicesChanged) patch.choices = this.formChoices();
  }
  return patch;
}
```

### Types DTO

```typescript
export interface CreateQuestionDto {
  type:           QuestionType;
  theme_id:       string;
  title:          string;
  choices?:       [string, string, string, string];  // MCQ uniquement
  correct_answer: string;
  level:          number;
  time_limit:     number;
  points:         number;
}

export type PatchQuestionDto = Partial<Omit<CreateQuestionDto, 'type'>>;

export interface MediaUploadResponse {
  id:              string;
  image_path:      string | null;
  audio_path:      string | null;
  last_updated_at: string;
}
```

### Endpoints consommés

| Appel | Endpoint | US serveur |
|---|---|---|
| Liste des questions | `GET /api/v1/questions` | US-005, US-006 |
| Liste des thèmes | `GET /api/v1/themes` | US-004 |
| Question par ID | `GET /api/v1/questions/:id` | US-005 |
| Création | `POST /api/v1/questions` | US-005 |
| Modification | `PATCH /api/v1/questions/:id` | US-007 |
| Suppression | `DELETE /api/v1/questions/:id` | US-005 |
| Upload média | `POST /api/v1/questions/:id/media` | US-016 |
| Suppression média | `DELETE /api/v1/questions/:id/media/:type` | US-016 |

---

## 📐 Périmètre

| Inclus | Exclu |
|---|---|
| Liste paginée des questions avec filtres serveur | Recherche full-text dans les titres (YAGNI) |
| Filtres : thème, type, niveau (plage), points (plage) | Filtres time_limit (non exposés dans l'UI — YAGNI) |
| Création MCQ et SPEED avec validation complète | Modification du type après création (immuable côté serveur) |
| Édition via PATCH (champs modifiés uniquement) | Édition via PUT (non exposé — YAGNI) |
| Upload image (jpeg, png, gif, webp ≤ 10 Mo) | Redimensionnement d'image (YAGNI) |
| Upload audio (mp3, wav, ogg ≤ 10 Mo) | Prévisualisation audio inline (YAGNI) |
| Suppression avec garde `QUESTION_IN_QUIZ` | Suppression en lot (YAGNI) |
| `ConfirmDialogComponent` pour suppression et suppression de média | Historique des modifications (YAGNI) |
| Tests unitaires et d'intégration (couverture ≥ 70 %) | Déploiement / CI-CD |

---

## 🔍 Points de vigilance

### Filtre de plage niveau et points — exclusivité côté serveur

Le serveur refuse la combinaison simultanée de `level` (valeur exacte) et `level_min`/`level_max`. Angular n'expose que les filtres de plage (`level_min`, `level_max`) — jamais `level` exact — pour éviter tout conflit. Si les deux bornes de plage sont vides, aucun paramètre de niveau n'est envoyé.

### Validation locale des médias avant upload

La validation de taille (≤ 10 Mo) et de type MIME doit être effectuée côté Angular **avant** l'envoi du fichier. Elle ne remplace pas la validation serveur mais améliore l'expérience utilisateur en évitant un aller-retour réseau pour des erreurs prévisibles. La validation MIME côté Angular repose sur `file.type` (navigateur) — moins fiable que la détection côté serveur, mais suffisante comme première barrière.

### Upload désactivé en mode création

L'upload est lié à `POST /api/v1/questions/:id/media` qui requiert un `id` existant. En mode création, la question n'existe pas encore — les zones de dépôt sont donc désactivées jusqu'après la soumission réussie du formulaire. Si le maître de jeu souhaite ajouter un média immédiatement après la création, il est redirigé vers la liste ; il peut ensuite rouvrir la question en édition.

### PATCH — ne pas envoyer un payload vide

Si `buildPatchPayload()` retourne un objet vide `{}` (aucun champ modifié), l'appel `PATCH` ne doit pas être émis. Angular navigue directement vers la liste avec un toast "Aucune modification détectée" — conforme au comportement serveur qui retournerait `200` sans mise à jour de `last_updated_at`, mais sans appel réseau inutile (KISS).

### Cohérence des choix et de la bonne réponse MCQ

La validation croisée `correct_answer ∈ choices` est effectuée côté Angular au moment de la soumission. Elle l'est aussi côté serveur — les deux niveaux de validation sont indépendants. La case radio indiquant la bonne réponse doit rester synchronisée avec la valeur textuelle du choix sélectionné : si l'utilisateur modifie le texte d'un choix après avoir coché sa case radio, Angular doit mettre à jour `formCorrectAnswer` pour refléter la nouvelle valeur.

---

## 🔗 Documents liés

| Document | Contenu |
|---|---|
| [VISION.md](VISION.md) | Description complète du projet |
| [CONVENTIONS-TECHNIQUES-ANGULAR.md](CONVENTIONS-TECHNIQUES-ANGULAR.md) | Stack, principes, conventions de code |
| [US-ANG-001 — Initialisation](US-ANG-001-init-session.md) | `AuthService`, `WebSocketService` |
| [US-005 — CRUD questions (serveur)](US-005-crud-questions.md) | Endpoints POST, GET, PUT, DELETE |
| [US-006 — Filtrage avancé (serveur)](US-006-questions-filtrage.md) | Paramètres de filtrage |
| [US-007 — PATCH questions (serveur)](US-007-questions-patch.md) | Sémantique JSON Merge Patch |
| [US-016 — Upload médias (serveur)](US-016-media-upload-questions.md) | Endpoints upload et suppression |

---

**Dernière mise à jour** : 2026-03-28
**Statut** : Rédigée — en attente d'implémentation (Sprint 2)
**Sprint** : 2
