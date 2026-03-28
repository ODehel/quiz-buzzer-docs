# US-ANG-009 — Gestion des thèmes

## 📋 Contexte projet

Voir [VISION.md](VISION.md) pour la description complète du projet et de ses quatre applications.

---

## 🎯 User Story

> **En tant que** maître de jeu,
> **je veux** créer, renommer et supprimer des thèmes de questions,
> **afin d'** organiser ma banque de questions par catégories cohérentes.

---

## ✅ Critères d'acceptance

> 🧪 **Exigence de couverture** — Voir [CONVENTIONS-TECHNIQUES-ANGULAR.md](CONVENTIONS-TECHNIQUES-ANGULAR.md). Couverture `ThemeService` ≥ 80 %. Couverture `ThemeListComponent` ≥ 70 %.

---

### Liste des thèmes — `ThemeListComponent`

#### Chargement initial

| # | Critère | Résultat attendu |
|---|---|---|
| CA-1 | Au chargement, `GET /api/v1/themes?page=1&limit=100` est appelé | Tous les thèmes en une seule page — le volume attendu (< 50) ne justifie pas de pagination côté UI |
| CA-2 | Chaque ligne affiche : nom du thème, date de création | Tri par date décroissante — garanti par le serveur |
| CA-3 | Le total de thèmes est affiché en en-tête | Issu du champ `total` de la réponse serveur |
| CA-4 | Si la liste est vide, un message d'invitation "Aucun thème — créez votre premier thème" est affiché | Pas de tableau vide |

---

### Création d'un thème

| # | Critère | Résultat attendu |
|---|---|---|
| CA-5 | Un bouton "Nouveau thème" ouvre un champ de saisie inline ou un dialogue minimal | Le champ reçoit le focus automatiquement à l'ouverture |
| CA-6 | La saisie est validée localement : non vide, commence par une majuscule, entre 3 et 40 caractères | Message d'erreur inline si invalide — aucun appel réseau |
| CA-7 | Si valide, `POST /api/v1/themes` est appelé avec `{ "name": "<nom>" }` | En cas de `201` : la liste est rechargée, toast "Thème créé", champ fermé |
| CA-8 | En cas de `409 THEME_ALREADY_EXISTS` : message d'erreur inline "Un thème porte déjà ce nom" | Le champ reste ouvert |
| CA-9 | La touche `Échap` ferme le champ sans appel réseau | Comportement clavier natif |
| CA-10 | La touche `Entrée` soumet le formulaire (équivalent au clic sur "Créer") | Comportement clavier natif |

---

### Renommage d'un thème

| # | Critère | Résultat attendu |
|---|---|---|
| CA-11 | Un clic sur le nom d'un thème (ou sur le bouton crayon) le place en mode édition inline | Le champ prérempli reçoit le focus — le nom original est conservé comme valeur initiale |
| CA-12 | Les mêmes règles de validation locale qu'à la création s'appliquent | Non vide, majuscule initiale, 3–40 caractères |
| CA-13 | Si les données sont identiques au nom original (comparaison insensible à la casse), aucun appel réseau n'est émis | Navigation directe vers la sortie du mode édition — conformité avec US-004 CA-22 côté serveur |
| CA-14 | Si modifié, `PUT /api/v1/themes/:id` est appelé avec `{ "name": "<nouveau_nom>" }` | En cas de `200` : la liste est mise à jour localement, toast "Thème renommé" |
| CA-15 | En cas de `409 THEME_ALREADY_EXISTS` : message d'erreur inline "Un thème porte déjà ce nom" | Le champ reste en mode édition |
| CA-16 | La touche `Échap` annule l'édition sans appel réseau | Le nom original est restauré |

---

### Suppression d'un thème

| # | Critère | Résultat attendu |
|---|---|---|
| CA-17 | Le bouton "Supprimer" ouvre `ConfirmDialogComponent` avec le nom du thème | La confirmation est requise avant tout appel réseau |
| CA-18 | Après confirmation, `DELETE /api/v1/themes/:id` est appelé | En cas de `204` : la ligne est retirée de la liste locale sans rechargement complet, toast "Thème supprimé" |
| CA-19 | En cas de `409 THEME_HAS_QUESTIONS` : message d'erreur "Ce thème contient des questions — supprimez ou réaffectez-les d'abord" | Pas de suppression — le dialog se ferme |

---

## 🔧 Spécifications techniques

Voir [CONVENTIONS-TECHNIQUES-ANGULAR.md](CONVENTIONS-TECHNIQUES-ANGULAR.md) pour la stack complète, les principes et les conventions de code.

### `ThemeService` — interface publique

```typescript
@Injectable({ providedIn: 'root' })
export class ThemeService {
  // Liste complète (pas de pagination UI)
  getAll(): Observable<PagedResponse<Theme>>;

  // Création
  create(name: string): Promise<Theme>;

  // Renommage
  update(id: string, name: string): Promise<Theme>;

  // Suppression
  delete(id: string): Promise<void>;
}
```

### `ThemeListComponent` — state local

```typescript
@Component({
  selector: 'app-theme-list',
  standalone: true,
  changeDetection: ChangeDetectionStrategy.OnPush
})
export class ThemeListComponent {
  private readonly themeService = inject(ThemeService);

  // Liste des thèmes
  protected readonly themes    = signal<Theme[]>([]);
  protected readonly total     = signal<number>(0);
  protected readonly isLoading = signal(true);

  // État du formulaire de création
  protected readonly isCreating  = signal(false);
  protected readonly newName     = signal('');
  protected readonly createError = signal<string | null>(null);

  // État d'édition inline — ID du thème en cours d'édition
  protected readonly editingId   = signal<string | null>(null);
  protected readonly editingName = signal('');
  protected readonly editError   = signal<string | null>(null);

  constructor() {
    this.load();
  }

  private load(): void {
    this.themeService.getAll()
      .pipe(takeUntilDestroyed())
      .subscribe(r => {
        this.themes.set(r.data);
        this.total.set(r.total);
        this.isLoading.set(false);
      });
  }
}
```

### Optimisation locale — suppression sans rechargement

```typescript
async onDelete(theme: Theme): Promise<void> {
  // Après 204, mise à jour locale du signal — pas de GET supplémentaire
  await this.themeService.delete(theme.id);
  this.themes.update(list => list.filter(t => t.id !== theme.id));
  this.total.update(n => n - 1);
}
```

### Interface `Theme`

```typescript
export interface Theme {
  id:              string;
  name:            string;
  created_at:      string;
  last_updated_at: string | null;
}
```

### Endpoints consommés

| Appel | Endpoint | US serveur |
|---|---|---|
| Liste des thèmes | `GET /api/v1/themes?limit=100` | US-004 |
| Création | `POST /api/v1/themes` | US-004 |
| Renommage | `PUT /api/v1/themes/:id` | US-004 |
| Suppression | `DELETE /api/v1/themes/:id` | US-004 |

---

## 📐 Périmètre

| Inclus | Exclu |
|---|---|
| Liste complète des thèmes (sans pagination UI) | Pagination côté UI (YAGNI — volume attendu < 50) |
| Création inline avec validation locale | Import de thèmes depuis un fichier (YAGNI) |
| Renommage inline avec détection de non-modification | Fusion de thèmes (YAGNI) |
| Suppression avec garde `THEME_HAS_QUESTIONS` | Réaffectation des questions avant suppression (YAGNI) |
| Mise à jour locale du signal après suppression (sans rechargement) | Navigation vers la liste des questions filtrées par thème (YAGNI) |
| Tests unitaires et d'intégration (couverture ≥ 70 %) | Déploiement / CI-CD |

---

## 🔍 Points de vigilance

### Validation locale — régime allégé

La regex complète côté serveur (`/^[\p{Lu}][\p{L}\p{N} '\-]{1,38}[\p{L}\p{N}]$/u`) n'est pas reproduite côté Angular (DRY — un seul point de vérité). Angular valide uniquement : non vide, commence par une majuscule, longueur 3–40. Les contraintes plus fines (caractères autorisés, fin par lettre/chiffre) sont validées par le serveur. Si la validation serveur échoue avec un `400 VALIDATION_ERROR`, un message générique "Nom invalide" est affiché.

### Détection de non-modification en édition

En mode édition, si le nom saisi (après `.trim()`) est identique au nom original (comparaison `.toLowerCase()`), aucun appel REST n'est émis — comportement conforme au CA-22 de l'US-004 serveur qui retournerait `200 OK` sans modifier `last_updated_at`. L'économie de l'appel réseau est préférable (KISS).

### Suppression — mise à jour locale vs rechargement

Après une suppression réussie (`204`), la liste est mise à jour localement via `signal.update()` sans déclencher un nouveau `GET /api/v1/themes`. Ce choix évite un aller-retour réseau inutile — le serveur vient de confirmer la suppression, l'état local peut être déduit avec certitude. Le compteur `total` est décrémenté en conséquence.

### `noActiveGameGuard` — accès conditionnel

`ThemeListComponent` est sur la route `/content/themes`, protégée par `noActiveGameGuard`. Si une partie est active, l'accès est bloqué et l'utilisateur est redirigé vers `/pilot/play`. La sidebar désactive visuellement le lien "Thèmes" dans ce cas (conforme à US-ANG-002 CA-21).

---

## 🔗 Documents liés

| Document | Contenu |
|---|---|
| [VISION.md](VISION.md) | Description complète du projet |
| [CONVENTIONS-TECHNIQUES-ANGULAR.md](CONVENTIONS-TECHNIQUES-ANGULAR.md) | Stack, principes, conventions de code |
| [US-ANG-002 — Tableau de bord](US-ANG-002-dashboard.md) | Désactivation des liens Contenu si partie active |
| [US-ANG-003 — Gestion des questions](US-ANG-003-gestion-questions.md) | `ThemeService` réutilisé dans `QuestionFormComponent` |
| [US-004 — CRUD des thèmes (serveur)](US-004-themes-crud.md) | Endpoints POST, GET, PUT, DELETE |

---

**Dernière mise à jour** : 2026-03-28
**Statut** : Implémentée
**Sprint** : 2
