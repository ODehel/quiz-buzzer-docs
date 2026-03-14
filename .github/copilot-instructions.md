# Instructions GitHub Copilot — Cahiers des charges Quiz Buzzer

Ce fichier définit le format, la structure et la charte graphique à respecter pour tous les cahiers des charges (User Stories) du projet **Quiz Buzzer**. Il est utilisé comme référence par GitHub Copilot pour garantir une cohérence entre les documents.

---

## 🌐 Langue et ton

- Tous les documents sont rédigés entièrement en **français**.
- Le titre de la User Story utilise le format **"En tant qu'"** devant une voyelle, **"En tant que"** devant une consonne.
- Les messages d'erreur JSON restent en **anglais** (convention API).
- Les commentaires dans les exemples de code restent en **français**.

---

## 📁 Convention de nommage des fichiers

```
US-XXX-description-en-kebab-case.md
```

- `XXX` : numéro à trois chiffres, complété par des zéros (ex. : `001`, `012`).
- `description` : titre court en kebab-case, sans accents, sans caractères spéciaux.
- Exemples : `US-001-server-startup.md`, `US-003-themes-crud.md`, `US-006-quiz-crud.md`.

---

## 🏗️ Structure générale d'un document

Chaque cahier des charges suit l'ordre de sections ci-dessous. Les sections marquées **[optionnel]** sont incluses uniquement si elles sont pertinentes pour la US concernée.

```
# US-XXX — Titre complet du cahier des charges

## 📋 Contexte projet
## 🎯 User Story
## ✅ Critères d'acceptance
## 🧪 Cas de tests — requêtes cURL        [optionnel — API REST et WebSocket]
## 🔧 Spécifications techniques
## 📡 Endpoint(s)                         [optionnel — US avec endpoint(s) HTTP]
## 🔐 Authentification et autorisation    [optionnel — US avec routes protégées]
## 📝 Logging structuré                   [optionnel — US avec événements loggés]
## 🌱 Seed — Description                  [optionnel — US avec données initiales]
## 🔌 Architecture [Composant]            [optionnel — US architecturale (WebSocket, etc.)]
## 🚨 Catalogue des erreurs               [optionnel — US avec API REST]
## 📐 Périmètre
## 🔍 Points de vigilance
```

Un séparateur `---` est placé **après chaque section** (avant la section suivante), sans exception.

---

## 📋 Section : Contexte projet

Contenu identique dans tous les documents :

```markdown
## 📋 Contexte projet

Le projet **Quiz Buzzer** se décompose en quatre applications :

| Application | Technologie | Rôle |
|---|---|---|
| **Buzzers** | PlatformIO / ESP32-S3 | Périphériques physiques de jeu |
| **App mobile** | Android / NFC | Configuration WiFi des buzzers |
| **App maître de jeu** | Angular | Interface de gestion des parties |
| **Serveur (hub)** | Node.js / JavaScript | Communication WebSocket entre l'app Angular et les buzzers, gestion du workflow des parties |
```

---

## 🎯 Section : User Story

Format en bloc de citation :

```markdown
## 🎯 User Story

> **En tant qu'** [acteur],
> **je veux** [action souhaitée],
> **afin de** [bénéfice / objectif].
```

- Utiliser `**En tant qu'**` devant une voyelle (a, e, i, o, u, y, h muet).
- Utiliser `**En tant que**` devant une consonne.
- Terminer chaque ligne par une virgule (sauf la dernière par un point).

---

## ✅ Section : Critères d'acceptance

### Structure

- Utiliser des sous-sections `###` pour regrouper les critères par opération ou thème.
- Nommer les sous-sections d'après l'opération HTTP et le endpoint : ex. `### Création — \`POST /api/v1/themes\``.

### Format du tableau

```markdown
| # | Critère | Résultat attendu |
|---|---|---|
| CA-1 | Description du critère | Résultat attendu (code HTTP, format de réponse, etc.) |
```

- Numéroter les critères **CA-1, CA-2, …** en recommençant à **CA-1** pour chaque nouvelle US.
- Pour un sous-critère d'un CA existant, utiliser le suffixe lettré : `CA-65b`.
- Les sous-sections standard pour une US CRUD REST sont :
  - `### Création — \`POST /api/v1/[ressource]\``
  - `### Lecture d'une ressource — \`GET /api/v1/[ressource]/:id\``
  - `### Lecture de la liste — \`GET /api/v1/[ressource]\``
  - `### Modification complète — \`PUT /api/v1/[ressource]/:id\``
  - `### Modification partielle — \`PATCH /api/v1/[ressource]/:id\`` (si PATCH implémenté)
  - `### Suppression — \`DELETE /api/v1/[ressource]/:id\``
  - `### Sécurité et transversalité`
- Le critère de couverture de tests appartient toujours à `### Sécurité et transversalité` avec le libellé : `Tests unitaires et d'intégration` / `Couverture de tests ≥ 90%`.

---

## 🧪 Section : Cas de tests — requêtes cURL

Présente pour toutes les US avec des endpoints REST ou WebSocket.

### En-tête de section

```markdown
## 🧪 Cas de tests — requêtes cURL

> **Variables** à définir avant d'exécuter les commandes :
> ```bash
> BASE_URL=http://localhost:3000
> TOKEN=<votre_token_JWT_admin>           # Obtenu via POST /api/v1/token (US-002)
> [AUTRES_VARIABLES]=<valeur>             # Description courte
> ```
```

### Format de chaque test

```markdown
**CA-X** — Description courte du cas → `CODE HTTP attendu`

```bash
curl -s -w "\n→ HTTP %{http_code}\n" -X [MÉTHODE] "$BASE_URL/api/v1/[ressource]" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{...}'
```
```

- Chaque test est précédé de son numéro CA en **gras** : `**CA-X**`.
- Les commandes `curl` utilisent systématiquement `-s -w "\n→ HTTP %{http_code}\n"`.
- Les sous-sections reprennent exactement les mêmes noms que dans `## ✅ Critères d'acceptance`.
- Les tests sont organisés par sous-section, dans le même ordre que les critères.

---

## 🔧 Section : Spécifications techniques

### Tableau principal

```markdown
## 🔧 Spécifications techniques

| Élément | Choix |
|---|---|
| Runtime | Node.js 24 LTS (dernière version stable disponible) |
| Langage | JavaScript (ES Modules) |
| Base de données | SQLite |
| Tests | Jest (dernière version stable disponible) |
| Identifiants | UUIDv7 généré côté Node.js |
| Horodatage | ISO 8601 UTC (millisecondes), généré côté Node.js |
| Principes d'architecture | YAGNI, KISS, DRY, SOLID |
```

- La ligne `Base de données` est incluse uniquement si la US utilise SQLite.
- Les lignes `Identifiants` et `Horodatage` sont incluses uniquement si la US manipule des entités persistées avec UUIDv7.
- Des lignes supplémentaires peuvent être ajoutées selon la US (ex. : `Bibliothèque WebSocket | \`ws\` (dernière version stable disponible)`).

### Schéma SQL

Inclure un bloc `sql` avec le `CREATE TABLE` pour toute table créée par la US. Convention de nommage : `T_NOM_ABR` pour la table, `ABR_COLONNE` pour chaque colonne.

### Convention JSON — snake_case

Inclure des exemples JSON (objet unitaire et liste paginée si applicable) avec :
- 2 espaces d'indentation.
- Champs en `snake_case`.
- Dates au format ISO 8601 UTC : `"2026-03-XXTHH:mm:ss.000Z"`.
- UUIDs au format `"018e4f5X-XXXX-7XXX-XXXX-XXXXXXXXXXXX"`.
- Champs optionnels non renseignés à `null`.

### Versioning API

```markdown
### Versioning API

```
Base URL : /api/v1
```
```

---

## ⚙️ Principes d'architecture fondamentaux : KISS, DRY, YAGNI et SOLID

> **Exigence non négociable** — Toute implémentation d'une US doit **scrupuleusement** respecter ces quatre principes. Ils prévalent sur toute optimisation prématurée, généralisation non justifiée ou complexité inutile.

Ces principes sont rappelés dans chaque US via un encadré visible dans la section `## 🔧 Spécifications techniques`.

---

### KISS — *Keep It Simple, Stupid*

**Règle** : Choisir systématiquement la solution la plus simple qui satisfait le besoin.

| ✅ À faire | ❌ À éviter |
|---|---|
| Une fonction unique par responsabilité | Des fonctions « couteaux suisses » multi-rôles |
| Un middleware `authenticate` qui vérifie le JWT | Un middleware qui authentifie ET autorise ET rate-limite |
| Des réponses d'erreur avec un format JSON fixe `{ status, error, message }` | Des structures d'erreur variables selon le contexte |
| Un handler de route plat et lisible | Des abstractions en couches non justifiées |

**Dans le projet** : chaque route handler reçoit ses dépendances par injection (db, config, authenticate, authorize, RateLimiter) et ne fait qu'une seule chose — traiter un endpoint précis.

---

### DRY — *Don't Repeat Yourself*

**Règle** : Toute logique dupliquée doit être extraite dans une fonction ou un module partagé.

| ✅ À faire | ❌ À éviter |
|---|---|
| Middlewares `authenticate` et `authorize` définis une fois dans l'US-003, réutilisés dans toutes les US suivantes | Réécrire la vérification JWT dans chaque route handler |
| Fonction utilitaire `normalizeString(str)` pour trim + collapse | Répéter `str.trim().replace(/\s+/g, ' ')` dans chaque route |
| Format d'erreur JSON centralisé dans un helper `sendError(res, status, code, message)` | Construire la réponse d'erreur manuellement dans chaque handler |
| Constante `UUID_REGEX` importée depuis un module commun | Redéfinir la regex UUID dans chaque fichier de validation |

**Dans le projet** : les middlewares, helpers de validation et utilitaires UUIDv7/horodatage sont **définis une seule fois** et importés partout.

---

### YAGNI — *You Ain't Gonna Need It*

**Règle** : Ne pas implémenter de fonctionnalité qui n'est pas explicitement demandée dans la US courante.

| ✅ À faire | ❌ À éviter |
|---|---|
| Implémenter uniquement les endpoints décrits dans `## 📡 Endpoints` | Ajouter `GET /api/v1/quizzes/:id` parce que « ça sera sûrement utile » |
| Pagination simple (page + limit) | Un moteur de recherche full-text non demandé |
| Stocker les tokens en mémoire pour le WebSocket | Implémenter un système de refresh token non spécifié |
| Filtres listés dans `## 📡 Endpoints — Paramètres de filtrage` | Ajouter des filtres supplémentaires « par anticipation » |

**Dans le projet** : la colonne **Exclu** de chaque `## 📐 Périmètre` documente explicitement ce qui est hors périmètre YAGNI.

---

### SOLID — *Five object-oriented design principles*

**Règle** : Appliquer les cinq principes de conception orientée objet/module.

| Principe | Application dans le projet |
|---|---|
| **S** — Single Responsibility | Chaque middleware, handler, helper a une responsabilité unique. `authenticate` = vérifier le JWT. `authorize(role)` = vérifier le rôle. Séparés, jamais fusionnés. |
| **O** — Open/Closed | `authorize(role)` est paramétré par rôle : ouvert à l'extension (nouveaux rôles) sans modification de son code. |
| **L** — Liskov Substitution | Les handlers de routes respectent la même signature `(req, res, next)` : interchangeables dans la chaîne Express. |
| **I** — Interface Segregation | Les dépendances sont injectées précisément (db, config, authenticate…). Un handler ne reçoit pas un objet global monolithique. |
| **D** — Dependency Inversion | Les routes dépendent d'abstractions (les middlewares injectés), pas d'implémentations concrètes importées directement. |

---

### Rappel dans chaque US

Chaque `## 🔧 Spécifications techniques` doit inclure, immédiatement après le tableau principal :

```markdown
> ⚠️ **Exigence fondamentale** — Toute implémentation de cette US doit scrupuleusement respecter les principes **KISS** (solutions simples), **DRY** (pas de duplication), **YAGNI** (pas de fonctionnalité prématurée) et **SOLID** (architecture modulaire et responsabilités séparées). Ces principes prévalent sur toute optimisation prématurée ou généralisation non justifiée par un besoin immédiat documenté.
```

---

## 📡 Section : Endpoint(s)

### Tableau principal

```markdown
## 📡 Endpoints

| Méthode | URL | Description | Auth | Code succès |
|---|---|---|---|---|
| `POST` | `/api/v1/[ressource]` | Créer une ressource | Bearer (admin) | `201 Created` |
| `GET` | `/api/v1/[ressource]` | Lister les ressources (paginé) | Bearer (admin) | `200 OK` |
| `GET` | `/api/v1/[ressource]/:id` | Récupérer une ressource | Bearer (admin) | `200 OK` |
| `PUT` | `/api/v1/[ressource]/:id` | Modifier entièrement une ressource | Bearer (admin) | `200 OK` |
| `DELETE` | `/api/v1/[ressource]/:id` | Supprimer une ressource | Bearer (admin) | `204 No Content` |
```

- Pour un endpoint unique (ex. US-002), utiliser `## 📡 Endpoint` (singulier).

### Tableau des headers Allow

```markdown
### Headers `Allow` par ressource

| URL | Méthodes autorisées |
|---|---|
| `/api/v1/[ressource]` | `GET, POST` |
| `/api/v1/[ressource]/:id` | `GET, PUT, DELETE` |
```

---

## 🔐 Section : Authentification et autorisation

Présente pour toutes les US avec des routes REST protégées (hors US-002 qui définit le mécanisme).

```markdown
## 🔐 Authentification et autorisation

### Mécanisme

Toutes les routes de cette US sont protégées par un **JSON Web Token (JWT)** transmis via le header HTTP `Authorization`.

| Élément | Valeur |
|---|---|
| Type de token | JWT |
| Algorithme de signature | HS256 (symétrique) |
| Transmission | Header `Authorization: Bearer <token>` |
| Secret de signature | Variable d'environnement `JWT_SECRET` (min 32 caractères) |
| Durée de validité | 1 heure (3600s), configurable via variable d'environnement `JWT_EXPIRATION` |
| Renouvellement | Reconnexion via `POST /api/v1/token` (US-002) |

### Structure du payload JWT

```json
{
  "sub": "018e4f5a-8c3b-7d2e-9f1a-4b5c6d7e8f9a",
  "role": "admin",
  "iat": 1741358400,
  "exp": 1741362000
}
```

| Claim | Type | Description |
|---|---|---|
| `sub` (subject) | `string` | UUIDv7 de l'utilisateur (claim standard RFC 7519) |
| `role` | `string` | Rôle de l'utilisateur (`"admin"` pour cette US) |
| `iat` (issued at) | `number` | Timestamp Unix de l'émission (automatique) |
| `exp` (expiration) | `number` | Timestamp Unix d'expiration (automatique) |

### Architecture middleware — Réutilisation de l'US-003

Les middlewares `authenticate` et `authorize('admin')` créés dans l'US-003 sont réutilisés tels quels sur toutes les routes de cette US, conformément aux principes DRY et Open/Closed (SOLID).

**Application sur les routes :**

```javascript
router.[méthode]('/api/v1/[ressource]',       authenticate, authorize('admin'), [handler]);
```
```

---

## 📝 Section : Logging structuré

Inclure pour les US avec des événements à logger (connexions, authentifications, etc.).

```markdown
## 📝 Logging structuré

### Format JSON

**[Nom de l'événement] :**

```json
{
  "timestamp": "2026-03-XXTHH:mm:ss.000Z",
  "level": "INFO",
  "event": "NOM_EVENEMENT_SNAKE_UPPER",
  "champ1": "valeur1"
}
```
```

- Niveaux de log : `"INFO"` (succès), `"WARN"` (échec métier), `"ERROR"` (erreur serveur).
- Noms d'événements en `SCREAMING_SNAKE_CASE`.

---

## 🚨 Section : Catalogue des erreurs

### Tableau principal

```markdown
## 🚨 Catalogue des erreurs

| Code erreur | Code HTTP | Message | Contexte |
|---|---|---|---|
| `VALIDATION_ERROR` | `400` | _(dynamique selon le cas)_ | Description du contexte d'erreur |
| `UNAUTHORIZED` | `401` | `"Authentication token is missing or invalid."` | Token absent/expiré/invalide |
| `FORBIDDEN` | `403` | `"You do not have permission to perform this action."` | Rôle insuffisant |
| `NOT_FOUND` | `404` | `"The requested [ressource] was not found."` | Ressource inexistante |
| `METHOD_NOT_ALLOWED` | `405` | _(dynamique)_ | Méthode non supportée |
| `INTERNAL_SERVER_ERROR` | `500` | `"An unexpected error occurred. Please try again later."` | Erreur serveur |
```

- La colonne s'appelle **`Code HTTP`** (pas simplement `HTTP`).
- Les messages d'erreur standards sont en **anglais**, entre backticks quand fixes, avec `_(dynamique)_` quand variables.
- Inclure **systématiquement** les erreurs `UNAUTHORIZED`, `FORBIDDEN` (si routes protégées), `METHOD_NOT_ALLOWED`, `INTERNAL_SERVER_ERROR`.

### Bloc JSON de référence

```markdown
### Format standard des réponses d'erreur

```json
{
  "status": 400,
  "error": "VALIDATION_ERROR",
  "message": "Description de l'erreur."
}
```
```

---

## 📐 Section : Périmètre

```markdown
## 📐 Périmètre

| Inclus | Exclu |
|---|---|
| Ce qui est implémenté dans cette US | Ce qui est hors périmètre (YAGNI, US dédiées, etc.) |
```

- Toujours inclure une ligne pour les tests : `Tests unitaires et d'intégration (couverture ≥ 90%)`.
- Toujours inclure `Déploiement / CI-CD` dans la colonne **Exclu**.
- Utiliser des cellules vides dans la colonne Exclu si la colonne Inclus a plus de lignes.

---

## 🔍 Section : Points de vigilance

```markdown
## 🔍 Points de vigilance

### Titre du point de vigilance

Paragraphe explicatif...

### Autre point de vigilance

Paragraphe explicatif...
```

- Chaque point est un `###` avec un titre descriptif.
- Le texte est rédigé en phrases complètes.
- Points récurrents à inclure dans les US CRUD REST :
  - **Unicité insensible à la casse** (si contrainte UNIQUE COLLATE NOCASE).
  - **PUT/PATCH sans changement réel** (`last_updated_at` non modifié).
  - **Sécurité des erreurs 500** (pas de stack trace dans la réponse).
  - **Middlewares réutilisables (DRY / SOLID)** (pour les US qui réutilisent `authenticate`/`authorize`).

---

## 🎨 Règles de mise en forme (charte graphique)

### Séparateurs

- Un `---` est placé **après chaque section H2**, immédiatement avant la prochaine section H2.
- Pas de `---` à l'intérieur d'une section (sauf exception narrative justifiée).

### Tableaux

- Format compact sans espaces autour des `|` : `| Colonne | Valeur |`
- Séparateur de colonnes : `|---|---|---|` (tirets simples, sans espaces).

### Blocs de code

- Toujours spécifier le langage : `json`, `sql`, `javascript`, `bash`, `env`, `markdown`.
- Indentation de **2 espaces** dans tous les blocs JSON et SQL.

### Gras et code inline

- `**Gras**` pour les termes clés, principes, noms de bibliothèques.
- `` `Code inline` `` pour les valeurs techniques : méthodes HTTP, chemins d'URL, noms de champs, codes d'erreur, variables d'environnement.

### Emojis de sections

| Emoji | Section |
|---|---|
| 📋 | Contexte projet |
| 🎯 | User Story |
| ✅ | Critères d'acceptance |
| 🧪 | Cas de tests — requêtes cURL |
| 🔧 | Spécifications techniques |
| 📡 | Endpoint(s) |
| 🔐 | Authentification et autorisation / Mécanisme d'authentification |
| 📝 | Logging structuré |
| 🌱 | Seed |
| 🔌 | Architecture [Composant] |
| 🚨 | Catalogue des erreurs |
| 📐 | Périmètre |
| 🔍 | Points de vigilance |

---

## 🔢 Conventions de données

| Donnée | Convention |
|---|---|
| Identifiants | UUIDv7, format `018eXXXX-XXXX-7XXX-XXXX-XXXXXXXXXXXX` |
| Dates | ISO 8601 UTC avec millisecondes : `"2026-03-XXTHH:mm:ss.000Z"` |
| Noms de champs JSON | `snake_case` |
| Noms de tables SQLite | `T_NOM_ABR` (ex. `T_THEME_THM`) |
| Noms de colonnes SQLite | `ABR_NOM_COLONNE` (ex. `THM_NAME`) |
| Champs optionnels non renseignés | `null` |
| Pagination par défaut | `page=1`, `limit=20`, `limit` plafonné à `100` |
| Tri par défaut des listes | Date de création décroissante (plus récents en premier) |

---

## ✅ Checklist de validation d'un nouveau document

Avant de valider un nouveau cahier des charges, vérifier :

- [ ] Le fichier est nommé `US-XXX-description.md` avec le bon numéro séquentiel.
- [ ] La page de couverture (`diagrams/covers/US-XXX-cover.png`) est présente et référencée **avant** le titre `# US-XXX`.
- [ ] La section `## 📋 Contexte projet` contient le tableau des 4 applications (contenu identique à tous les autres US).
- [ ] La User Story est en bloc de citation (`>`) avec **En tant qu'**, **je veux**, **afin de**.
- [ ] Les critères d'acceptance sont numérotés **CA-1** à **CA-N** (restart à 1 pour chaque US).
- [ ] La section `## 🔄 Diagramme de flux` est présente après `## ✅ Critères d'acceptance`, avec le PNG du diagramme Mermaid (thème `forest`).
- [ ] La section `## 🧪 Cas de tests` est présente pour toute US avec un ou plusieurs endpoints REST.
- [ ] Le tableau des spécifications techniques utilise les formulations complètes (`dernière version stable disponible`).
- [ ] L'encadré **Exigence fondamentale KISS/DRY/YAGNI/SOLID** est présent immédiatement après le tableau principal des spécifications techniques.
- [ ] La colonne du catalogue des erreurs s'appelle **`Code HTTP`**.
- [ ] La section `## 🔐 Authentification et autorisation` est présente pour toute US avec des routes protégées par JWT.
- [ ] Un `---` est présent après chaque section H2.
- [ ] Les exemples JSON utilisent des dates au format ISO 8601 UTC : `"2026-03-XXTHH:mm:ss.000Z"`.
- [ ] Les erreurs standards sont incluses dans le catalogue : `UNAUTHORIZED`, `FORBIDDEN`, `METHOD_NOT_ALLOWED`, `INTERNAL_SERVER_ERROR`.
- [ ] La section `## 📐 Périmètre` inclut `Déploiement / CI-CD` dans Exclu et la couverture ≥ 90% dans Inclus.
