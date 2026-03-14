![Page de couverture — US-004](diagrams/covers/US-004-cover.png)

# US-004 — CRUD des questions

## 📋 Contexte projet

Le projet **Quiz Buzzer** se décompose en quatre applications :

| Application | Technologie | Rôle |
|---|---|---|
| **Buzzers** | PlatformIO / ESP32-S3 | Périphériques physiques de jeu |
| **App mobile** | Android / NFC | Configuration WiFi des buzzers |
| **App maître de jeu** | Angular | Interface de gestion des parties |
| **Serveur (hub)** | Node.js / JavaScript | Communication WebSocket entre l'app Angular et les buzzers, gestion du workflow des parties |

---

## 🎯 User Story

> **En tant qu'** administrateur,
> **je veux** pouvoir créer, lire, modifier (totalement ou partiellement) et supprimer des questions,
> **afin de** constituer la banque de questions du quiz.

---

## ✅ Critères d'acceptance

### Création — `POST /api/v1/questions`

| # | Critère | Résultat attendu |
|---|---|---|
| CA-1 | Créer une question MCQ avec tous les champs valides | `201 Created` avec la question créée (id, type, theme_id, title, choices, correct_answer, level, time_limit, points, image_path: null, audio_path: null, created_at, last_updated_at: null) |
| CA-2 | Créer une question SPEED avec tous les champs valides | `201 Created` avec la question créée (id, type, theme_id, title, correct_answer, level, time_limit, points, image_path: null, audio_path: null, created_at, last_updated_at: null) — `choices` absent de la réponse |
| CA-3 | Le titre est normalisé avant validation (trim + collapse des espaces multiples) | `"  Quelle est   la capitale  " → "Quelle est la capitale"` |
| CA-4 | Le titre doit commencer par une majuscule Unicode et faire entre 10 et 250 caractères (émojis acceptés) | Sinon → `400 VALIDATION_ERROR` |
| CA-5 | L'unicité du titre est insensible à la casse | Titre existant → `409 QUESTION_ALREADY_EXISTS` |
| CA-6 | Le champ `type` doit valoir `"MCQ"` ou `"SPEED"` | Sinon → `400 VALIDATION_ERROR` |
| CA-7 | Le champ `theme_id` doit référencer un thème existant | Sinon → `400 INVALID_THEME` |
| CA-8 | Le champ `theme_id` doit être un UUID valide | Sinon → `400 INVALID_UUID` |
| CA-9 | Pour une question MCQ, `choices` est obligatoire : tableau d'exactement 4 chaînes non vides (1–40 caractères chacune), toutes distinctes (insensible à la casse) | Sinon → `400 VALIDATION_ERROR` |
| CA-10 | Pour une question MCQ, `correct_answer` est obligatoire et doit correspondre exactement (insensible à la casse) à l'un des 4 `choices` | Sinon → `400 VALIDATION_ERROR` |
| CA-11 | Pour une question SPEED, `choices` doit être absent du body | Présent → `400 VALIDATION_ERROR` |
| CA-12 | Pour une question SPEED, `correct_answer` est obligatoire (1–40 caractères) | Sinon → `400 VALIDATION_ERROR` |
| CA-13 | Le champ `level` doit être un entier entre 1 et 5 | Sinon → `400 VALIDATION_ERROR` |
| CA-14 | Le champ `time_limit` doit être un entier entre 5 et 60 (en secondes) | Sinon → `400 VALIDATION_ERROR` |
| CA-15 | Le champ `points` doit être un entier entre 1 et 50 | Sinon → `400 VALIDATION_ERROR` |
| CA-16 | L'ID est un UUIDv7 généré côté Node.js | Format UUID standard (8-4-4-4-12) |
| CA-17 | Les horodatages sont en ISO 8601 UTC, générés côté Node.js | `created_at` rempli, `last_updated_at` à `null` |
| CA-18 | Les champs `image_path` et `audio_path` ne sont pas acceptés dans le body du POST | Présents → `400 UNKNOWN_FIELDS` |
| CA-19 | Le body ne doit contenir que les champs autorisés selon le type | Champs inconnus → `400 UNKNOWN_FIELDS` |
| CA-20 | Le `Content-Type` doit être `application/json` | Sinon → `415 UNSUPPORTED_MEDIA_TYPE` |

### Lecture d'une question — `GET /api/v1/questions/:id`

| # | Critère | Résultat attendu |
|---|---|---|
| CA-21 | Récupérer une question MCQ par son ID | `200 OK` avec la question complète (incluant `choices`) |
| CA-22 | Récupérer une question SPEED par son ID | `200 OK` avec la question (sans `choices`) |
| CA-23 | ID inexistant | `404 NOT_FOUND` |
| CA-24 | ID mal formé (pas un UUID valide) | `400 INVALID_UUID` |
| CA-25 | Un body éventuel est ignoré silencieusement | Aucune erreur |

### Lecture de la liste — `GET /api/v1/questions`

| # | Critère | Résultat attendu |
|---|---|---|
| CA-26 | Récupérer la liste des questions avec pagination | `200 OK` avec objet `{ data, page, limit, total, total_pages }` |
| CA-27 | Tri par date de création descendant (plus récents en premier) | Ordre garanti |
| CA-28 | Paramètres de pagination par défaut : `page=1`, `limit=20` | Appliqués si non fournis |
| CA-29 | Le paramètre `limit` est plafonné à `100` | `limit=200` → `400 INVALID_PAGINATION` |
| CA-30 | Paramètres de pagination invalides (négatifs, zéro, non numériques) | `400 INVALID_PAGINATION` |
| CA-31 | Page au-delà du total | `200 OK` avec `data: []` et métadonnées correctes |
| CA-32 | Aucune question en base | `200 OK` avec `{ "data": [], "page": 1, "limit": 20, "total": 0, "total_pages": 0 }` |
| CA-33 | Filtrage par `theme_id` (UUID valide, thème existant) | Seules les questions du thème sont retournées |
| CA-34 | Filtrage par `type` (`MCQ` ou `SPEED`) | Seules les questions du type sont retournées |
| CA-35 | Filtrage par `level` (valeur exacte : `?level=3`) | Seules les questions du niveau sont retournées |
| CA-36 | Filtrage par `level_min` et/ou `level_max` | Filtre par plage (bornes incluses) |
| CA-37 | Filtrage par `time_limit_min` et/ou `time_limit_max` | Filtre par plage (bornes incluses) |
| CA-38 | Filtrage par `points_min` et/ou `points_max` | Filtre par plage (bornes incluses) |
| CA-39 | Combinaison de plusieurs filtres | Les filtres sont combinés en ET logique |
| CA-40 | `theme_id` inexistant en base | `400 INVALID_FILTER` |
| CA-41 | `type` invalide (ni `MCQ` ni `SPEED`) | `400 INVALID_FILTER` |
| CA-42 | Valeurs numériques invalides pour `level`, `level_min`, `level_max`, `time_limit_min`, `time_limit_max`, `points_min`, `points_max` | `400 INVALID_FILTER` |
| CA-43 | Plage incohérente (`level_min` > `level_max`, etc.) | `400 INVALID_FILTER` |
| CA-44 | `level` et `level_min`/`level_max` présents simultanément | `400 INVALID_FILTER` |

### Modification complète — `PUT /api/v1/questions/:id`

| # | Critère | Résultat attendu |
|---|---|---|
| CA-45 | Modifier une question MCQ avec tous les champs valides | `200 OK` avec la question mise à jour, `last_updated_at` mis à jour |
| CA-46 | Modifier une question SPEED avec tous les champs valides | `200 OK` avec la question mise à jour, `last_updated_at` mis à jour |
| CA-47 | Toutes les règles de validation du POST s'appliquent | Trim, collapse, regex, unicité, cohérence type/champs |
| CA-48 | Le `type` envoyé doit correspondre au type actuel de la question | Changement de type → `400 TYPE_CHANGE_NOT_ALLOWED` |
| CA-49 | Les données envoyées sont identiques à l'existant | `200 OK` avec la question inchangée, `last_updated_at` **non modifié** |
| CA-50 | L'ID peut être présent dans le body ; s'il l'est, il doit correspondre à l'URL | Sinon → `400 ID_MISMATCH` |
| CA-51 | Le titre est déjà pris par une autre question | `409 QUESTION_ALREADY_EXISTS` |
| CA-52 | ID inexistant | `404 NOT_FOUND` |
| CA-53 | Le `Content-Type` doit être `application/json` | Sinon → `415 UNSUPPORTED_MEDIA_TYPE` |
| CA-54 | Le body ne doit contenir que les champs autorisés (tous les champs métier requis, `id` optionnel ; **`image_path` et `audio_path` ne sont pas gérés par ce endpoint**) | Champs inconnus (dont `image_path`/`audio_path`) → `400 UNKNOWN_FIELDS` |
| CA-55 | Le PUT exige tous les champs métier : `type`, `theme_id`, `title`, `correct_answer`, `level`, `time_limit`, `points` (+ `choices` si MCQ). **Les champs médias `image_path` et `audio_path` ne sont ni créés, ni modifiés, ni réinitialisés par ce PUT et conservent leur valeur actuelle**. | Champ métier manquant → `400 VALIDATION_ERROR` |

### Modification partielle — `PATCH /api/v1/questions/:id`

| # | Critère | Résultat attendu |
|---|---|---|
| CA-56 | Modifier partiellement une question (un ou plusieurs champs) | `200 OK` avec la question mise à jour, `last_updated_at` mis à jour |
| CA-57 | Format JSON Merge Patch (RFC 7396) : champ absent = non modifié | Seuls les champs présents dans le body sont modifiés |
| CA-58 | Un champ obligatoire envoyé à `null` | `400 VALIDATION_ERROR` (les champs obligatoires ne peuvent pas être nullifiés) |
| CA-59 | `choices` envoyé à `null` sur une question MCQ | `400 VALIDATION_ERROR` |
| CA-60 | Le champ `type` n'est pas modifiable via PATCH | Présent → `400 TYPE_CHANGE_NOT_ALLOWED` |
| CA-61 | Le champ `id` n'est pas modifiable via PATCH | Présent → `400 UNKNOWN_FIELDS` |
| CA-62 | Modification du `theme_id` vers un thème existant | `200 OK`, le `theme_id` est mis à jour |
| CA-63 | Modification du `theme_id` vers un thème inexistant | `400 INVALID_THEME` |
| CA-64 | Modification du `title` : mêmes règles de validation que le POST | Trim, collapse, majuscule, longueur, unicité |
| CA-65 | Modification de `choices` : mêmes règles que le POST (4 éléments, 1–40 car., distincts) | Validation complète |
| CA-65b | PATCH avec `choices` sur une question SPEED | `400 VALIDATION_ERROR` (une question SPEED ne peut pas avoir de `choices`) |
| CA-66 | Modification de `correct_answer` : doit correspondre à un des `choices` actuels (ou des nouveaux `choices` si fournis dans le même PATCH) | Sinon → `400 VALIDATION_ERROR` |
| CA-67 | Modification de `level`, `time_limit`, `points` : mêmes règles que le POST | Plages respectées |
| CA-68 | Modification de `image_path` : doit être une chaîne non vide ou `null` (pour supprimer) | Chaîne vide → `400 VALIDATION_ERROR` |
| CA-69 | Modification de `audio_path` : doit être une chaîne non vide ou `null` (pour supprimer) | Chaîne vide → `400 VALIDATION_ERROR` |
| CA-70 | Les données envoyées sont identiques à l'existant | `200 OK` avec la question inchangée, `last_updated_at` **non modifié** |
| CA-71 | ID inexistant | `404 NOT_FOUND` |
| CA-72 | Le `Content-Type` doit être `application/json` | Sinon → `415 UNSUPPORTED_MEDIA_TYPE` |
| CA-73 | Body vide `{}` | `200 OK` avec la question inchangée (aucune modification) |

### Suppression — `DELETE /api/v1/questions/:id`

| # | Critère | Résultat attendu |
|---|---|---|
| CA-74 | Supprimer une question existante | `204 No Content` sans body |
| CA-75 | ID inexistant | `404 NOT_FOUND` |
| CA-76 | ID mal formé | `400 INVALID_UUID` |
| CA-77 | Un body éventuel est ignoré silencieusement | Aucune erreur |

### Garde de suppression des thèmes (implémentation du TODO CA-30 de l'US-003)

| # | Critère | Résultat attendu |
|---|---|---|
| CA-78 | Suppression d'un thème qui a des questions associées | `409 THEME_HAS_QUESTIONS` avec message `"Cannot delete this theme: questions are still associated with it."` |
| CA-79 | Suppression d'un thème sans questions associées | `204 No Content` (comportement inchangé) |

### Sécurité et transversalité

| # | Critère | Résultat attendu |
|---|---|---|
| CA-80 | Toutes les routes sont protégées par un Bearer token | Token absent/invalide/expiré → `401 UNAUTHORIZED` |
| CA-81 | Seul l'administrateur peut effectuer des opérations | Rôle insuffisant → `403 FORBIDDEN` |
| CA-82 | Rate limiting : max 100 requêtes par minute | Dépassement → `429 RATE_LIMIT_EXCEEDED` avec header `Retry-After: 30` |
| CA-83 | Méthode HTTP non supportée sur une ressource | `405 METHOD_NOT_ALLOWED` avec header `Allow` adapté à la ressource |
| CA-84 | Erreur serveur inattendue | `500 INTERNAL_SERVER_ERROR` (aucun détail technique exposé) |
| CA-85 | Tests unitaires et d'intégration | Couverture de tests ≥ 90% |

---

## 🔄 Diagramme de flux

![Diagramme de flux — US-004 — CRUD des questions](diagrams/US-004-crud-questions.png)

---

## 🧪 Cas de tests — requêtes cURL

> **Variables** à définir avant d'exécuter les commandes :
> ```bash
> BASE_URL=http://localhost:3000
> TOKEN=<votre_token_JWT_admin>                              # Obtenu via POST /api/v1/token (US-002)
> THEME_ID=018e4f5a-8c3b-7d2e-9f1a-4b5c6d7e8f9a            # UUID d'un thème existant en base
> THEME_EMPTY_ID=018e4f5b-1a2b-7c3d-8e4f-5a6b7c8d9e0f      # UUID d'un thème sans question liée
> TOKEN_USER=<token_JWT_avec_role_user>                      # Token non-admin (pour CA-81)
> QUESTION_MCQ_ID=018e4f5c-2b3c-7d4e-9f5a-6b7c8d9e0f1a     # UUID d'une question MCQ existante
> QUESTION_SPD_ID=018e4f5d-3c4d-7e5f-0a6b-7c8d9e0f1a2b     # UUID d'une question SPEED existante
> ```

### Création — `POST /api/v1/questions`

**CA-1** — Créer une question MCQ avec tous les champs valides → `201 Created`

```bash
curl -s -w "\n→ HTTP %{http_code}\n" -X POST "$BASE_URL/api/v1/questions" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "type": "MCQ",
    "theme_id": "018e4f5a-8c3b-7d2e-9f1a-4b5c6d7e8f9a",
    "title": "Quelle est la capitale de la France ?",
    "choices": ["Paris", "Lyon", "Marseille", "Toulouse"],
    "correct_answer": "Paris",
    "level": 1,
    "time_limit": 30,
    "points": 10
  }'
```

**CA-2** — Créer une question SPEED avec tous les champs valides → `201 Created` (`choices` absent de la réponse)

```bash
curl -s -w "\n→ HTTP %{http_code}\n" -X POST "$BASE_URL/api/v1/questions" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "type": "SPEED",
    "theme_id": "018e4f5a-8c3b-7d2e-9f1a-4b5c6d7e8f9a",
    "title": "Quel est le plus grand océan du monde ?",
    "correct_answer": "Pacifique",
    "level": 2,
    "time_limit": 15,
    "points": 20
  }'
```

**CA-3** — Titre normalisé (trim + collapse des espaces multiples) → `201 Created` avec titre normalisé

```bash
curl -s -w "\n→ HTTP %{http_code}\n" -X POST "$BASE_URL/api/v1/questions" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "type": "SPEED",
    "theme_id": "018e4f5a-8c3b-7d2e-9f1a-4b5c6d7e8f9a",
    "title": "  Quel est   le plus long   fleuve du monde  ?",
    "correct_answer": "Nil",
    "level": 2,
    "time_limit": 20,
    "points": 15
  }'
# Vérifier que "title" dans la réponse vaut "Quel est le plus long fleuve du monde ?"
```

**CA-4** — Titre ne commençant pas par une majuscule Unicode → `400 VALIDATION_ERROR`

```bash
curl -s -w "\n→ HTTP %{http_code}\n" -X POST "$BASE_URL/api/v1/questions" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "type": "SPEED",
    "theme_id": "018e4f5a-8c3b-7d2e-9f1a-4b5c6d7e8f9a",
    "title": "quel est le plus long fleuve du monde ?",
    "correct_answer": "Nil",
    "level": 2,
    "time_limit": 20,
    "points": 15
  }'
```

**CA-5** — Doublon de titre (insensible à la casse) → `409 QUESTION_ALREADY_EXISTS`

```bash
# Prérequis : la question "Quelle est la capitale de la France ?" existe déjà (cf. CA-1)
curl -s -w "\n→ HTTP %{http_code}\n" -X POST "$BASE_URL/api/v1/questions" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "type": "MCQ",
    "theme_id": "018e4f5a-8c3b-7d2e-9f1a-4b5c6d7e8f9a",
    "title": "QUELLE EST LA CAPITALE DE LA FRANCE ?",
    "choices": ["Paris", "Lyon", "Marseille", "Toulouse"],
    "correct_answer": "Paris",
    "level": 1,
    "time_limit": 30,
    "points": 10
  }'
```

**CA-6** — Type invalide → `400 VALIDATION_ERROR`

```bash
curl -s -w "\n→ HTTP %{http_code}\n" -X POST "$BASE_URL/api/v1/questions" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "type": "OPEN",
    "theme_id": "018e4f5a-8c3b-7d2e-9f1a-4b5c6d7e8f9a",
    "title": "Qui a peint la Joconde ?",
    "correct_answer": "Léonard de Vinci",
    "level": 3,
    "time_limit": 30,
    "points": 10
  }'
```

**CA-7** — `theme_id` inexistant → `400 INVALID_THEME`

```bash
curl -s -w "\n→ HTTP %{http_code}\n" -X POST "$BASE_URL/api/v1/questions" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "type": "SPEED",
    "theme_id": "018e4f5a-0000-0000-0000-000000000000",
    "title": "Qui a peint la Joconde ?",
    "correct_answer": "Léonard de Vinci",
    "level": 3,
    "time_limit": 30,
    "points": 10
  }'
```

**CA-8** — `theme_id` mal formé (pas un UUID valide) → `400 INVALID_UUID`

```bash
curl -s -w "\n→ HTTP %{http_code}\n" -X POST "$BASE_URL/api/v1/questions" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "type": "SPEED",
    "theme_id": "not-a-valid-uuid",
    "title": "Qui a peint la Joconde ?",
    "correct_answer": "Léonard de Vinci",
    "level": 3,
    "time_limit": 30,
    "points": 10
  }'
```

**CA-9** — MCQ avec `choices` invalide (3 éléments au lieu de 4) → `400 VALIDATION_ERROR`

```bash
curl -s -w "\n→ HTTP %{http_code}\n" -X POST "$BASE_URL/api/v1/questions" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "type": "MCQ",
    "theme_id": "018e4f5a-8c3b-7d2e-9f1a-4b5c6d7e8f9a",
    "title": "Dans quel pays se trouve la Tour Eiffel ?",
    "choices": ["France", "Italie", "Espagne"],
    "correct_answer": "France",
    "level": 1,
    "time_limit": 30,
    "points": 10
  }'
```

**CA-10** — MCQ avec `correct_answer` absent des `choices` → `400 VALIDATION_ERROR`

```bash
curl -s -w "\n→ HTTP %{http_code}\n" -X POST "$BASE_URL/api/v1/questions" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "type": "MCQ",
    "theme_id": "018e4f5a-8c3b-7d2e-9f1a-4b5c6d7e8f9a",
    "title": "Dans quel pays se trouve la Tour Eiffel ?",
    "choices": ["France", "Italie", "Espagne", "Portugal"],
    "correct_answer": "Allemagne",
    "level": 1,
    "time_limit": 30,
    "points": 10
  }'
```

**CA-11** — SPEED avec `choices` présent → `400 VALIDATION_ERROR`

```bash
curl -s -w "\n→ HTTP %{http_code}\n" -X POST "$BASE_URL/api/v1/questions" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "type": "SPEED",
    "theme_id": "018e4f5a-8c3b-7d2e-9f1a-4b5c6d7e8f9a",
    "title": "Dans quel pays se trouve la Tour Eiffel ?",
    "choices": ["France", "Italie", "Espagne", "Portugal"],
    "correct_answer": "France",
    "level": 1,
    "time_limit": 30,
    "points": 10
  }'
```

**CA-12** — SPEED sans `correct_answer` → `400 VALIDATION_ERROR`

```bash
curl -s -w "\n→ HTTP %{http_code}\n" -X POST "$BASE_URL/api/v1/questions" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "type": "SPEED",
    "theme_id": "018e4f5a-8c3b-7d2e-9f1a-4b5c6d7e8f9a",
    "title": "Dans quel pays se trouve la Tour Eiffel ?",
    "level": 1,
    "time_limit": 30,
    "points": 10
  }'
```

**CA-13** — `level` hors plage (valeur > 5) → `400 VALIDATION_ERROR`

```bash
curl -s -w "\n→ HTTP %{http_code}\n" -X POST "$BASE_URL/api/v1/questions" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "type": "SPEED",
    "theme_id": "018e4f5a-8c3b-7d2e-9f1a-4b5c6d7e8f9a",
    "title": "Quelle est la vitesse de la lumière ?",
    "correct_answer": "300 000 km/s",
    "level": 6,
    "time_limit": 30,
    "points": 10
  }'
```

**CA-14** — `time_limit` hors plage (valeur < 5) → `400 VALIDATION_ERROR`

```bash
curl -s -w "\n→ HTTP %{http_code}\n" -X POST "$BASE_URL/api/v1/questions" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "type": "SPEED",
    "theme_id": "018e4f5a-8c3b-7d2e-9f1a-4b5c6d7e8f9a",
    "title": "Quelle est la vitesse de la lumière ?",
    "correct_answer": "300 000 km/s",
    "level": 3,
    "time_limit": 2,
    "points": 10
  }'
```

**CA-15** — `points` hors plage (valeur > 50) → `400 VALIDATION_ERROR`

```bash
curl -s -w "\n→ HTTP %{http_code}\n" -X POST "$BASE_URL/api/v1/questions" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "type": "SPEED",
    "theme_id": "018e4f5a-8c3b-7d2e-9f1a-4b5c6d7e8f9a",
    "title": "Quelle est la vitesse de la lumière ?",
    "correct_answer": "300 000 km/s",
    "level": 3,
    "time_limit": 30,
    "points": 100
  }'
```

**CA-16** — L'ID retourné est un UUIDv7 → vérifier le format dans la réponse `201`

```bash
curl -s -X POST "$BASE_URL/api/v1/questions" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "type": "SPEED",
    "theme_id": "018e4f5a-8c3b-7d2e-9f1a-4b5c6d7e8f9a",
    "title": "Combien de planètes compte le système solaire ?",
    "correct_answer": "8",
    "level": 1,
    "time_limit": 10,
    "points": 5
  }'
# Vérifier que le champ "id" de la réponse respecte le format UUID (8-4-4-4-12)
# et que le 4ème bloc commence par "7" (version UUIDv7)
```

**CA-17** — Horodatages ISO 8601 UTC → `created_at` rempli, `last_updated_at` à `null`

```bash
curl -s -X POST "$BASE_URL/api/v1/questions" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "type": "SPEED",
    "theme_id": "018e4f5a-8c3b-7d2e-9f1a-4b5c6d7e8f9a",
    "title": "Quel est le symbole chimique de l'\''or ?",
    "correct_answer": "Au",
    "level": 2,
    "time_limit": 15,
    "points": 10
  }'
# Vérifier : "created_at" est une date ISO 8601 UTC (ex. "2026-03-09T14:30:00.000Z")
# et "last_updated_at" vaut null
```

**CA-18** — `image_path` ou `audio_path` dans le body du POST → `400 UNKNOWN_FIELDS`

```bash
curl -s -w "\n→ HTTP %{http_code}\n" -X POST "$BASE_URL/api/v1/questions" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "type": "SPEED",
    "theme_id": "018e4f5a-8c3b-7d2e-9f1a-4b5c6d7e8f9a",
    "title": "Quel est le symbole chimique de l'\''argent ?",
    "correct_answer": "Ag",
    "level": 2,
    "time_limit": 15,
    "points": 10,
    "image_path": "/images/argent.jpg"
  }'
```

**CA-19** — Champ inconnu dans le body → `400 UNKNOWN_FIELDS`

```bash
curl -s -w "\n→ HTTP %{http_code}\n" -X POST "$BASE_URL/api/v1/questions" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "type": "SPEED",
    "theme_id": "018e4f5a-8c3b-7d2e-9f1a-4b5c6d7e8f9a",
    "title": "Quel est le symbole chimique de l'\''argent ?",
    "correct_answer": "Ag",
    "level": 2,
    "time_limit": 15,
    "points": 10,
    "difficulty": "easy"
  }'
```

**CA-20** — `Content-Type` incorrect → `415 UNSUPPORTED_MEDIA_TYPE`

```bash
curl -s -w "\n→ HTTP %{http_code}\n" -X POST "$BASE_URL/api/v1/questions" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: text/plain" \
  -d '{"type":"SPEED","theme_id":"018e4f5a-8c3b-7d2e-9f1a-4b5c6d7e8f9a","title":"Test du content type post","correct_answer":"Test","level":1,"time_limit":10,"points":5}'
```

### Lecture d'une question — `GET /api/v1/questions/:id`

**CA-21** — Récupérer une question MCQ → `200 OK` avec `choices`

```bash
curl -s -w "\n→ HTTP %{http_code}\n" -X GET "$BASE_URL/api/v1/questions/$QUESTION_MCQ_ID" \
  -H "Authorization: Bearer $TOKEN"
```

**CA-22** — Récupérer une question SPEED → `200 OK` sans `choices`

```bash
curl -s -w "\n→ HTTP %{http_code}\n" -X GET "$BASE_URL/api/v1/questions/$QUESTION_SPD_ID" \
  -H "Authorization: Bearer $TOKEN"
```

**CA-23** — ID inexistant → `404 NOT_FOUND`

```bash
curl -s -w "\n→ HTTP %{http_code}\n" -X GET "$BASE_URL/api/v1/questions/018e4f5a-0000-0000-0000-000000000000" \
  -H "Authorization: Bearer $TOKEN"
```

**CA-24** — ID mal formé → `400 INVALID_UUID`

```bash
curl -s -w "\n→ HTTP %{http_code}\n" -X GET "$BASE_URL/api/v1/questions/not-a-valid-uuid" \
  -H "Authorization: Bearer $TOKEN"
```

**CA-25** — Body éventuel ignoré silencieusement → aucune erreur

```bash
curl -s -w "\n→ HTTP %{http_code}\n" -X GET "$BASE_URL/api/v1/questions/$QUESTION_MCQ_ID" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"ignored": "body"}'
```

### Lecture de la liste — `GET /api/v1/questions`

**CA-26** — Récupérer la liste paginée → `200 OK` avec `{ data, page, limit, total, total_pages }`

```bash
curl -s -w "\n→ HTTP %{http_code}\n" -X GET "$BASE_URL/api/v1/questions" \
  -H "Authorization: Bearer $TOKEN"
```

**CA-27** — Tri par date de création descendant → vérifier que `data[0].created_at` ≥ `data[1].created_at`

```bash
curl -s -X GET "$BASE_URL/api/v1/questions" \
  -H "Authorization: Bearer $TOKEN"
# Inspecter la réponse : data[0].created_at doit être >= data[1].created_at
```

**CA-28** — Paramètres de pagination par défaut (`page=1`, `limit=20`) appliqués si non fournis

```bash
curl -s -X GET "$BASE_URL/api/v1/questions" \
  -H "Authorization: Bearer $TOKEN"
# Vérifier "page": 1 et "limit": 20 dans la réponse
```

**CA-29** — `limit` > 100 → `400 INVALID_PAGINATION`

```bash
curl -s -w "\n→ HTTP %{http_code}\n" -X GET "$BASE_URL/api/v1/questions?limit=200" \
  -H "Authorization: Bearer $TOKEN"
```

**CA-30** — `page` invalide (valeur négative) → `400 INVALID_PAGINATION`

```bash
curl -s -w "\n→ HTTP %{http_code}\n" -X GET "$BASE_URL/api/v1/questions?page=-1" \
  -H "Authorization: Bearer $TOKEN"
```

**CA-31** — Page au-delà du total → `200 OK` avec `data: []` et métadonnées correctes

```bash
curl -s -w "\n→ HTTP %{http_code}\n" -X GET "$BASE_URL/api/v1/questions?page=9999" \
  -H "Authorization: Bearer $TOKEN"
```

**CA-32** — Aucune question en base → `200 OK` avec `{ "data": [], "page": 1, "limit": 20, "total": 0, "total_pages": 0 }`

```bash
# À exécuter sur une base vide (ou après avoir supprimé toutes les questions)
curl -s -w "\n→ HTTP %{http_code}\n" -X GET "$BASE_URL/api/v1/questions" \
  -H "Authorization: Bearer $TOKEN"
```

**CA-33** — Filtrage par `theme_id` → seules les questions du thème retournées

```bash
curl -s -w "\n→ HTTP %{http_code}\n" -X GET "$BASE_URL/api/v1/questions?theme_id=$THEME_ID" \
  -H "Authorization: Bearer $TOKEN"
```

**CA-34** — Filtrage par `type=MCQ` → seules les questions MCQ retournées

```bash
curl -s -w "\n→ HTTP %{http_code}\n" -X GET "$BASE_URL/api/v1/questions?type=MCQ" \
  -H "Authorization: Bearer $TOKEN"
```

**CA-35** — Filtrage par `level` exact → seules les questions du niveau retournées

```bash
curl -s -w "\n→ HTTP %{http_code}\n" -X GET "$BASE_URL/api/v1/questions?level=3" \
  -H "Authorization: Bearer $TOKEN"
```

**CA-36** — Filtrage par plage `level_min`/`level_max` (bornes incluses)

```bash
curl -s -w "\n→ HTTP %{http_code}\n" -X GET "$BASE_URL/api/v1/questions?level_min=2&level_max=4" \
  -H "Authorization: Bearer $TOKEN"
```

**CA-37** — Filtrage par plage `time_limit_min`/`time_limit_max`

```bash
curl -s -w "\n→ HTTP %{http_code}\n" -X GET "$BASE_URL/api/v1/questions?time_limit_min=10&time_limit_max=30" \
  -H "Authorization: Bearer $TOKEN"
```

**CA-38** — Filtrage par plage `points_min`/`points_max`

```bash
curl -s -w "\n→ HTTP %{http_code}\n" -X GET "$BASE_URL/api/v1/questions?points_min=5&points_max=20" \
  -H "Authorization: Bearer $TOKEN"
```

**CA-39** — Combinaison de plusieurs filtres (ET logique)

```bash
curl -s -w "\n→ HTTP %{http_code}\n" -X GET "$BASE_URL/api/v1/questions?type=MCQ&level_min=1&level_max=3&theme_id=$THEME_ID" \
  -H "Authorization: Bearer $TOKEN"
```

**CA-40** — `theme_id` inexistant en base → `400 INVALID_FILTER`

```bash
curl -s -w "\n→ HTTP %{http_code}\n" -X GET "$BASE_URL/api/v1/questions?theme_id=018e4f5a-0000-0000-0000-000000000000" \
  -H "Authorization: Bearer $TOKEN"
```

**CA-41** — `type` invalide → `400 INVALID_FILTER`

```bash
curl -s -w "\n→ HTTP %{http_code}\n" -X GET "$BASE_URL/api/v1/questions?type=INVALID" \
  -H "Authorization: Bearer $TOKEN"
```

**CA-42** — Valeur numérique invalide pour un filtre → `400 INVALID_FILTER`

```bash
curl -s -w "\n→ HTTP %{http_code}\n" -X GET "$BASE_URL/api/v1/questions?level=abc" \
  -H "Authorization: Bearer $TOKEN"
```

**CA-43** — Plage incohérente (`level_min` > `level_max`) → `400 INVALID_FILTER`

```bash
curl -s -w "\n→ HTTP %{http_code}\n" -X GET "$BASE_URL/api/v1/questions?level_min=4&level_max=2" \
  -H "Authorization: Bearer $TOKEN"
```

**CA-44** — `level` et `level_min`/`level_max` présents simultanément → `400 INVALID_FILTER`

```bash
curl -s -w "\n→ HTTP %{http_code}\n" -X GET "$BASE_URL/api/v1/questions?level=3&level_min=1&level_max=4" \
  -H "Authorization: Bearer $TOKEN"
```

### Modification complète — `PUT /api/v1/questions/:id`

**CA-45** — Modifier une question MCQ avec tous les champs valides → `200 OK`, `last_updated_at` mis à jour

```bash
curl -s -w "\n→ HTTP %{http_code}\n" -X PUT "$BASE_URL/api/v1/questions/$QUESTION_MCQ_ID" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "type": "MCQ",
    "theme_id": "018e4f5a-8c3b-7d2e-9f1a-4b5c6d7e8f9a",
    "title": "Quelle est la capitale de la France (mise à jour) ?",
    "choices": ["Paris", "Lyon", "Bordeaux", "Toulouse"],
    "correct_answer": "Paris",
    "level": 2,
    "time_limit": 20,
    "points": 15
  }'
```

**CA-46** — Modifier une question SPEED avec tous les champs valides → `200 OK`, `last_updated_at` mis à jour

```bash
curl -s -w "\n→ HTTP %{http_code}\n" -X PUT "$BASE_URL/api/v1/questions/$QUESTION_SPD_ID" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "type": "SPEED",
    "theme_id": "018e4f5a-8c3b-7d2e-9f1a-4b5c6d7e8f9a",
    "title": "Quel est le plus grand océan du monde (mise à jour) ?",
    "correct_answer": "Pacifique",
    "level": 3,
    "time_limit": 20,
    "points": 25
  }'
```

**CA-47** — Règles de validation du POST s'appliquent (ex. titre trop court) → `400 VALIDATION_ERROR`

```bash
curl -s -w "\n→ HTTP %{http_code}\n" -X PUT "$BASE_URL/api/v1/questions/$QUESTION_SPD_ID" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "type": "SPEED",
    "theme_id": "018e4f5a-8c3b-7d2e-9f1a-4b5c6d7e8f9a",
    "title": "Court",
    "correct_answer": "Test",
    "level": 1,
    "time_limit": 30,
    "points": 10
  }'
```

**CA-48** — Changement de type → `400 TYPE_CHANGE_NOT_ALLOWED`

```bash
# QUESTION_MCQ_ID est de type MCQ, on tente de la passer en SPEED
curl -s -w "\n→ HTTP %{http_code}\n" -X PUT "$BASE_URL/api/v1/questions/$QUESTION_MCQ_ID" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "type": "SPEED",
    "theme_id": "018e4f5a-8c3b-7d2e-9f1a-4b5c6d7e8f9a",
    "title": "Quelle est la capitale de la France ?",
    "correct_answer": "Paris",
    "level": 1,
    "time_limit": 30,
    "points": 10
  }'
```

**CA-49** — Données identiques à l'existant → `200 OK`, `last_updated_at` non modifié

```bash
# Envoyer exactement les mêmes données que la question actuelle
curl -s -w "\n→ HTTP %{http_code}\n" -X PUT "$BASE_URL/api/v1/questions/$QUESTION_SPD_ID" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "type": "SPEED",
    "theme_id": "018e4f5a-8c3b-7d2e-9f1a-4b5c6d7e8f9a",
    "title": "Quel est le plus grand océan du monde ?",
    "correct_answer": "Pacifique",
    "level": 2,
    "time_limit": 15,
    "points": 20
  }'
# Vérifier que last_updated_at n'a pas changé par rapport à avant l'appel
```

**CA-50** — `id` dans le body ne correspond pas à l'URL → `400 ID_MISMATCH`

```bash
curl -s -w "\n→ HTTP %{http_code}\n" -X PUT "$BASE_URL/api/v1/questions/$QUESTION_SPD_ID" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "id": "018e4f5a-0000-0000-0000-000000000001",
    "type": "SPEED",
    "theme_id": "018e4f5a-8c3b-7d2e-9f1a-4b5c6d7e8f9a",
    "title": "Quel est le plus grand océan du monde ?",
    "correct_answer": "Pacifique",
    "level": 2,
    "time_limit": 15,
    "points": 20
  }'
```

**CA-51** — Titre déjà pris par une autre question → `409 QUESTION_ALREADY_EXISTS`

```bash
# QUESTION_SPD_ID est SPEED, tenter de lui donner le titre de la MCQ (QUESTION_MCQ_ID)
curl -s -w "\n→ HTTP %{http_code}\n" -X PUT "$BASE_URL/api/v1/questions/$QUESTION_SPD_ID" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "type": "SPEED",
    "theme_id": "018e4f5a-8c3b-7d2e-9f1a-4b5c6d7e8f9a",
    "title": "Quelle est la capitale de la France ?",
    "correct_answer": "Paris",
    "level": 2,
    "time_limit": 15,
    "points": 20
  }'
```

**CA-52** — ID inexistant → `404 NOT_FOUND`

```bash
curl -s -w "\n→ HTTP %{http_code}\n" -X PUT "$BASE_URL/api/v1/questions/018e4f5a-0000-0000-0000-000000000000" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "type": "SPEED",
    "theme_id": "018e4f5a-8c3b-7d2e-9f1a-4b5c6d7e8f9a",
    "title": "Question inexistante à modifier ?",
    "correct_answer": "Test",
    "level": 1,
    "time_limit": 30,
    "points": 10
  }'
```

**CA-53** — `Content-Type` incorrect → `415 UNSUPPORTED_MEDIA_TYPE`

```bash
curl -s -w "\n→ HTTP %{http_code}\n" -X PUT "$BASE_URL/api/v1/questions/$QUESTION_SPD_ID" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: text/plain" \
  -d '{"type":"SPEED","theme_id":"018e4f5a-8c3b-7d2e-9f1a-4b5c6d7e8f9a","title":"Test du content type put","correct_answer":"Test","level":1,"time_limit":30,"points":10}'
```

**CA-54** — `image_path` dans le body du PUT → `400 UNKNOWN_FIELDS`

```bash
curl -s -w "\n→ HTTP %{http_code}\n" -X PUT "$BASE_URL/api/v1/questions/$QUESTION_SPD_ID" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "type": "SPEED",
    "theme_id": "018e4f5a-8c3b-7d2e-9f1a-4b5c6d7e8f9a",
    "title": "Quel est le plus grand océan du monde ?",
    "correct_answer": "Pacifique",
    "level": 2,
    "time_limit": 15,
    "points": 20,
    "image_path": "/images/ocean.jpg"
  }'
```

**CA-55** — Champ métier manquant dans le PUT → `400 VALIDATION_ERROR`

```bash
# correct_answer, level, time_limit et points sont absents
curl -s -w "\n→ HTTP %{http_code}\n" -X PUT "$BASE_URL/api/v1/questions/$QUESTION_SPD_ID" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "type": "SPEED",
    "theme_id": "018e4f5a-8c3b-7d2e-9f1a-4b5c6d7e8f9a",
    "title": "Quel est le plus grand océan du monde ?"
  }'
```

### Modification partielle — `PATCH /api/v1/questions/:id`

**CA-56** — Modifier partiellement une question (un champ) → `200 OK`, `last_updated_at` mis à jour

```bash
curl -s -w "\n→ HTTP %{http_code}\n" -X PATCH "$BASE_URL/api/v1/questions/$QUESTION_SPD_ID" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"level": 3}'
```

**CA-57** — Champ absent du body = non modifié (JSON Merge Patch RFC 7396)

```bash
# Envoyer uniquement "points" et vérifier que les autres champs sont inchangés
curl -s -w "\n→ HTTP %{http_code}\n" -X PATCH "$BASE_URL/api/v1/questions/$QUESTION_SPD_ID" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"points": 25}'
# Vérifier que title, level, time_limit, correct_answer n'ont pas changé
```

**CA-58** — Champ obligatoire envoyé à `null` → `400 VALIDATION_ERROR`

```bash
curl -s -w "\n→ HTTP %{http_code}\n" -X PATCH "$BASE_URL/api/v1/questions/$QUESTION_SPD_ID" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"correct_answer": null}'
```

**CA-59** — `choices` à `null` sur une question MCQ → `400 VALIDATION_ERROR`

```bash
curl -s -w "\n→ HTTP %{http_code}\n" -X PATCH "$BASE_URL/api/v1/questions/$QUESTION_MCQ_ID" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"choices": null}'
```

**CA-60** — Tentative de modification du `type` via PATCH → `400 TYPE_CHANGE_NOT_ALLOWED`

```bash
curl -s -w "\n→ HTTP %{http_code}\n" -X PATCH "$BASE_URL/api/v1/questions/$QUESTION_SPD_ID" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"type": "MCQ"}'
```

**CA-61** — Tentative de modification de l'`id` via PATCH → `400 UNKNOWN_FIELDS`

```bash
curl -s -w "\n→ HTTP %{http_code}\n" -X PATCH "$BASE_URL/api/v1/questions/$QUESTION_SPD_ID" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"id": "018e4f5a-0000-0000-0000-000000000001"}'
```

**CA-62** — Modification du `theme_id` vers un thème existant → `200 OK`

```bash
curl -s -w "\n→ HTTP %{http_code}\n" -X PATCH "$BASE_URL/api/v1/questions/$QUESTION_SPD_ID" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"theme_id": "018e4f5b-1a2b-7c3d-8e4f-5a6b7c8d9e0f"}'
```

**CA-63** — Modification du `theme_id` vers un thème inexistant → `400 INVALID_THEME`

```bash
curl -s -w "\n→ HTTP %{http_code}\n" -X PATCH "$BASE_URL/api/v1/questions/$QUESTION_SPD_ID" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"theme_id": "018e4f5a-0000-0000-0000-000000000000"}'
```

**CA-64** — Modification du `title` : règles de validation invalides → `400 VALIDATION_ERROR`

```bash
curl -s -w "\n→ HTTP %{http_code}\n" -X PATCH "$BASE_URL/api/v1/questions/$QUESTION_SPD_ID" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"title": "trop court"}'
```

**CA-65** — Modification de `choices` : 4 éléments valides et distincts → `200 OK`

```bash
curl -s -w "\n→ HTTP %{http_code}\n" -X PATCH "$BASE_URL/api/v1/questions/$QUESTION_MCQ_ID" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"choices": ["Paris", "Berlin", "Madrid", "Rome"], "correct_answer": "Paris"}'
```

**CA-65b** — `choices` sur une question SPEED → `400 VALIDATION_ERROR`

```bash
curl -s -w "\n→ HTTP %{http_code}\n" -X PATCH "$BASE_URL/api/v1/questions/$QUESTION_SPD_ID" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"choices": ["A", "B", "C", "D"]}'
```

**CA-66** — `correct_answer` ne correspondant pas aux `choices` actuels → `400 VALIDATION_ERROR`

```bash
curl -s -w "\n→ HTTP %{http_code}\n" -X PATCH "$BASE_URL/api/v1/questions/$QUESTION_MCQ_ID" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"correct_answer": "Nairobi"}'
# "Nairobi" n'est pas dans les choices actuels de la question
```

**CA-67** — Modification de `level` hors plage → `400 VALIDATION_ERROR`

```bash
curl -s -w "\n→ HTTP %{http_code}\n" -X PATCH "$BASE_URL/api/v1/questions/$QUESTION_SPD_ID" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"level": 10}'
```

**CA-68** — `image_path` : chaîne vide → `400 VALIDATION_ERROR` ; `null` → `200 OK` (suppression)

```bash
# Chaîne vide → 400
curl -s -w "\n→ HTTP %{http_code}\n" -X PATCH "$BASE_URL/api/v1/questions/$QUESTION_SPD_ID" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"image_path": ""}'

# null → 200 (supprime image_path)
curl -s -w "\n→ HTTP %{http_code}\n" -X PATCH "$BASE_URL/api/v1/questions/$QUESTION_SPD_ID" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"image_path": null}'
```

**CA-69** — `audio_path` : chaîne vide → `400 VALIDATION_ERROR` ; `null` → `200 OK` (suppression)

```bash
# Chaîne vide → 400
curl -s -w "\n→ HTTP %{http_code}\n" -X PATCH "$BASE_URL/api/v1/questions/$QUESTION_SPD_ID" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"audio_path": ""}'

# null → 200 (supprime audio_path)
curl -s -w "\n→ HTTP %{http_code}\n" -X PATCH "$BASE_URL/api/v1/questions/$QUESTION_SPD_ID" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"audio_path": null}'
```

**CA-70** — Données identiques à l'existant → `200 OK`, `last_updated_at` non modifié

```bash
# Si "Pacifique" est déjà la valeur actuelle de correct_answer, last_updated_at ne doit pas changer
curl -s -w "\n→ HTTP %{http_code}\n" -X PATCH "$BASE_URL/api/v1/questions/$QUESTION_SPD_ID" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"correct_answer": "Pacifique"}'
```

**CA-71** — ID inexistant → `404 NOT_FOUND`

```bash
curl -s -w "\n→ HTTP %{http_code}\n" -X PATCH "$BASE_URL/api/v1/questions/018e4f5a-0000-0000-0000-000000000000" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"level": 2}'
```

**CA-72** — `Content-Type` incorrect → `415 UNSUPPORTED_MEDIA_TYPE`

```bash
curl -s -w "\n→ HTTP %{http_code}\n" -X PATCH "$BASE_URL/api/v1/questions/$QUESTION_SPD_ID" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: text/plain" \
  -d '{"level": 2}'
```

**CA-73** — Body vide `{}` → `200 OK` question inchangée

```bash
curl -s -w "\n→ HTTP %{http_code}\n" -X PATCH "$BASE_URL/api/v1/questions/$QUESTION_SPD_ID" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{}'
```

### Suppression — `DELETE /api/v1/questions/:id`

**CA-74** — Supprimer une question existante → `204 No Content`

```bash
curl -s -w "\n→ HTTP %{http_code}\n" -X DELETE "$BASE_URL/api/v1/questions/$QUESTION_SPD_ID" \
  -H "Authorization: Bearer $TOKEN"
```

**CA-75** — ID inexistant → `404 NOT_FOUND`

```bash
curl -s -w "\n→ HTTP %{http_code}\n" -X DELETE "$BASE_URL/api/v1/questions/018e4f5a-0000-0000-0000-000000000000" \
  -H "Authorization: Bearer $TOKEN"
```

**CA-76** — ID mal formé → `400 INVALID_UUID`

```bash
curl -s -w "\n→ HTTP %{http_code}\n" -X DELETE "$BASE_URL/api/v1/questions/not-a-valid-uuid" \
  -H "Authorization: Bearer $TOKEN"
```

**CA-77** — Body éventuel ignoré silencieusement → aucune erreur

```bash
curl -s -w "\n→ HTTP %{http_code}\n" -X DELETE "$BASE_URL/api/v1/questions/$QUESTION_SPD_ID" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"ignored": "body"}'
```

### Garde de suppression des thèmes

**CA-78** — Suppression d'un thème avec questions associées → `409 THEME_HAS_QUESTIONS`

```bash
# THEME_ID doit référencer un thème ayant au moins une question liée
curl -s -w "\n→ HTTP %{http_code}\n" -X DELETE "$BASE_URL/api/v1/themes/$THEME_ID" \
  -H "Authorization: Bearer $TOKEN"
```

**CA-79** — Suppression d'un thème sans questions → `204 No Content`

```bash
# THEME_EMPTY_ID référence un thème sans aucune question liée
curl -s -w "\n→ HTTP %{http_code}\n" -X DELETE "$BASE_URL/api/v1/themes/$THEME_EMPTY_ID" \
  -H "Authorization: Bearer $TOKEN"
```

### Sécurité et transversalité

**CA-80a** — Token absent → `401 UNAUTHORIZED`

```bash
curl -s -w "\n→ HTTP %{http_code}\n" -X GET "$BASE_URL/api/v1/questions"
```

**CA-80b** — Token invalide → `401 UNAUTHORIZED`

```bash
curl -s -w "\n→ HTTP %{http_code}\n" -X GET "$BASE_URL/api/v1/questions" \
  -H "Authorization: Bearer token_invalide"
```

**CA-81** — Rôle insuffisant (non admin) → `403 FORBIDDEN`

```bash
# TOKEN_USER est un token JWT valide avec rôle "user" (non admin)
curl -s -w "\n→ HTTP %{http_code}\n" -X GET "$BASE_URL/api/v1/questions" \
  -H "Authorization: Bearer $TOKEN_USER"
```

**CA-82** — Rate limiting dépassé (> 100 req/min) → `429 RATE_LIMIT_EXCEEDED` avec header `Retry-After: 30`

```bash
for i in $(seq 1 101); do
  curl -s -o /dev/null -w "%{http_code}\n" -X GET "$BASE_URL/api/v1/questions" \
    -H "Authorization: Bearer $TOKEN"
done
# La 101ème requête doit retourner 429 avec le header Retry-After: 30
```

**CA-83** — Méthode HTTP non supportée → `405 METHOD_NOT_ALLOWED` avec header `Allow` adapté

```bash
# DELETE sur la collection /api/v1/questions n'est pas supporté
curl -s -v -w "\n→ HTTP %{http_code}\n" -X DELETE "$BASE_URL/api/v1/questions" \
  -H "Authorization: Bearer $TOKEN"
# Vérifier : code 405 et header "Allow: GET, POST"
```

**CA-84** — Erreur serveur inattendue → `500 INTERNAL_SERVER_ERROR` sans détail technique

```bash
# Simuler une panne (ex. arrêter la base de données) puis envoyer une requête valide
curl -s -w "\n→ HTTP %{http_code}\n" -X GET "$BASE_URL/api/v1/questions" \
  -H "Authorization: Bearer $TOKEN"
# Résultat attendu : {"status":500,"error":"INTERNAL_SERVER_ERROR","message":"An unexpected error occurred. Please try again later."}
# Aucun détail technique (stack trace, message SQL, etc.) ne doit être exposé
```

**CA-85** — Couverture de tests ≥ 90%

```bash
# Depuis le répertoire du serveur Node.js
npm run test -- --coverage
# Inspecter le rapport Jest : lignes, fonctions et branches couvertes ≥ 90%
```

---

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

> ⚠️ **Exigence fondamentale** — Toute implémentation de cette US doit scrupuleusement respecter les principes **KISS** (solutions simples), **DRY** (pas de duplication), **YAGNI** (pas de fonctionnalité prématurée) et **SOLID** (architecture modulaire et responsabilités séparées). Ces principes prévalent sur toute optimisation prématurée ou généralisation non justifiée par un besoin immédiat documenté.

### Schéma de la table

```sql
CREATE TABLE T_QUESTION_QST
(
    QST_ID              TEXT PRIMARY KEY,
    QST_TYPE            TEXT NOT NULL CHECK (QST_TYPE IN ('MCQ', 'SPEED')),
    QST_THEME_ID        TEXT NOT NULL REFERENCES T_THEME_THM (THM_ID),
    QST_TITLE           TEXT NOT NULL UNIQUE COLLATE NOCASE,
    QST_CHOICE_A        TEXT DEFAULT NULL,
    QST_CHOICE_B        TEXT DEFAULT NULL,
    QST_CHOICE_C        TEXT DEFAULT NULL,
    QST_CHOICE_D        TEXT DEFAULT NULL,
    QST_CORRECT_ANSWER  TEXT NOT NULL,
    QST_LEVEL           INTEGER NOT NULL CHECK (QST_LEVEL BETWEEN 1 AND 5),
    QST_TIME_LIMIT      INTEGER NOT NULL CHECK (QST_TIME_LIMIT BETWEEN 5 AND 60),
    QST_POINTS          INTEGER NOT NULL CHECK (QST_POINTS BETWEEN 1 AND 50),
    QST_IMAGE_PATH      TEXT DEFAULT NULL,
    QST_AUDIO_PATH      TEXT DEFAULT NULL,
    QST_CREATED_AT      TEXT NOT NULL,
    QST_LAST_UPDATED_AT TEXT DEFAULT NULL
);
```

### Validation du titre — Pipeline de normalisation

```
Entrée brute
  → 1. Trim (suppression espaces début/fin)
  → 2. Collapse (espaces multiples → espace simple)
  → 3. Vérification non vide
  → 4. Vérification longueur (10–250 caractères)
  → 5. Vérification commence par une majuscule Unicode (\p{Lu})
  → 6. Vérification unicité (COLLATE NOCASE) en base
```

### Validation du correct_answer et des choices

```
correct_answer :
  → 1. Trim
  → 2. Vérification non vide (1–40 caractères)

choices (MCQ uniquement) :
  → 1. Tableau d'exactement 4 éléments
  → 2. Chaque élément : trim, non vide, 1–40 caractères
  → 3. Unicité des 4 choix (insensible à la casse)
  → 4. correct_answer doit correspondre à l'un des 4 choices (insensible à la casse)
```

### Versioning API

```
Base URL : /api/v1
```

### Format JSON — Convention snake_case

**Question MCQ unitaire :**

```json
{
  "id": "018e4f5c-2b3c-7d4e-9f5a-6b7c8d9e0f1a",
  "type": "MCQ",
  "theme_id": "018e4f5a-8c3b-7d2e-9f1a-4b5c6d7e8f9a",
  "title": "Quelle est la capitale de la France ?",
  "choices": ["Paris", "Lyon", "Marseille", "Toulouse"],
  "correct_answer": "Paris",
  "level": 1,
  "time_limit": 30,
  "points": 10,
  "image_path": null,
  "audio_path": null,
  "created_at": "2026-03-09T14:30:00.000Z",
  "last_updated_at": null
}
```

**Question SPEED unitaire :**

```json
{
  "id": "018e4f5d-3c4d-7e5f-0a6b-7c8d9e0f1a2b",
  "type": "SPEED",
  "theme_id": "018e4f5a-8c3b-7d2e-9f1a-4b5c6d7e8f9a",
  "title": "Quel est le plus grand océan du monde ?",
  "correct_answer": "Pacifique",
  "level": 2,
  "time_limit": 15,
  "points": 20,
  "image_path": null,
  "audio_path": null,
  "created_at": "2026-03-09T14:35:00.000Z",
  "last_updated_at": null
}
```

**Liste paginée :**

```json
{
  "data": [
    {
      "id": "018e4f5d-3c4d-7e5f-0a6b-7c8d9e0f1a2b",
      "type": "SPEED",
      "theme_id": "018e4f5a-8c3b-7d2e-9f1a-4b5c6d7e8f9a",
      "title": "Quel est le plus grand océan du monde ?",
      "correct_answer": "Pacifique",
      "level": 2,
      "time_limit": 15,
      "points": 20,
      "image_path": null,
      "audio_path": null,
      "created_at": "2026-03-09T14:35:00.000Z",
      "last_updated_at": null
    },
    {
      "id": "018e4f5c-2b3c-7d4e-9f5a-6b7c8d9e0f1a",
      "type": "MCQ",
      "theme_id": "018e4f5a-8c3b-7d2e-9f1a-4b5c6d7e8f9a",
      "title": "Quelle est la capitale de la France ?",
      "choices": ["Paris", "Lyon", "Marseille", "Toulouse"],
      "correct_answer": "Paris",
      "level": 1,
      "time_limit": 30,
      "points": 10,
      "image_path": null,
      "audio_path": null,
      "created_at": "2026-03-09T14:30:00.000Z",
      "last_updated_at": null
    }
  ],
  "page": 1,
  "limit": 20,
  "total": 2,
  "total_pages": 1
}
```

---

## 📡 Endpoints

| Méthode | URL | Description | Auth | Code succès |
|---|---|---|---|---|
| `POST` | `/api/v1/questions` | Créer une question | Bearer (admin) | `201 Created` |
| `GET` | `/api/v1/questions` | Lister les questions (paginé, filtrable) | Bearer (admin) | `200 OK` |
| `GET` | `/api/v1/questions/:id` | Récupérer une question | Bearer (admin) | `200 OK` |
| `PUT` | `/api/v1/questions/:id` | Modifier entièrement une question | Bearer (admin) | `200 OK` |
| `PATCH` | `/api/v1/questions/:id` | Modifier partiellement une question | Bearer (admin) | `200 OK` |
| `DELETE` | `/api/v1/questions/:id` | Supprimer une question | Bearer (admin) | `204 No Content` |

### Headers `Allow` par ressource

| URL | Méthodes autorisées |
|---|---|
| `/api/v1/questions` | `GET, POST` |
| `/api/v1/questions/:id` | `GET, PUT, PATCH, DELETE` |

### Paramètres de filtrage — `GET /api/v1/questions`

| Paramètre | Type | Description |
|---|---|---|
| `theme_id` | `string` (UUID) | Filtrer par thème (doit exister en base) |
| `type` | `string` | Filtrer par type (`MCQ` ou `SPEED`) |
| `level` | `integer` | Filtrer par niveau exact (1–5) |
| `level_min` | `integer` | Niveau minimum (borne incluse) |
| `level_max` | `integer` | Niveau maximum (borne incluse) |
| `time_limit_min` | `integer` | Durée minimum en secondes (borne incluse) |
| `time_limit_max` | `integer` | Durée maximum en secondes (borne incluse) |
| `points_min` | `integer` | Points minimum (borne incluse) |
| `points_max` | `integer` | Points maximum (borne incluse) |
| `page` | `integer` | Numéro de page (défaut : 1) |
| `limit` | `integer` | Nombre d'éléments par page (défaut : 20, max : 100) |

> **Règles de filtrage :**
> - Tous les filtres sont optionnels et combinables en **ET logique**.
> - Un filtre exact (`level`) et un filtre par plage (`level_min`/`level_max`) sur le même champ sont **mutuellement exclusifs** → `400 INVALID_FILTER`.
> - Les filtres par plage sont à **bornes incluses**.
> - Un `theme_id` inexistant en base retourne `400 INVALID_FILTER`.
> - Un `type` invalide retourne `400 INVALID_FILTER`.
> - Une plage incohérente (`min` > `max`) retourne `400 INVALID_FILTER`.

---

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
router.post('/api/v1/questions',       authenticate, authorize('admin'), createQuestion);
router.get('/api/v1/questions',        authenticate, authorize('admin'), listQuestions);
router.get('/api/v1/questions/:id',    authenticate, authorize('admin'), getQuestion);
router.put('/api/v1/questions/:id',    authenticate, authorize('admin'), updateQuestion);
router.patch('/api/v1/questions/:id',  authenticate, authorize('admin'), patchQuestion);
router.delete('/api/v1/questions/:id', authenticate, authorize('admin'), deleteQuestion);
```

---

## 🚨 Catalogue des erreurs

| Code erreur | Code HTTP | Message | Contexte |
|---|---|---|---|
| `VALIDATION_ERROR` | `400` | _(dynamique selon le cas)_ | Titre manquant/invalide, choices invalides, correct_answer invalide, level/time_limit/points hors plage, champ obligatoire à null en PATCH |
| `INVALID_UUID` | `400` | `"The provided ID is not a valid UUID."` | ID mal formé dans l'URL ou `theme_id` invalide dans le body |
| `INVALID_JSON` | `400` | `"Request body must be valid JSON."` | Corps non parseable |
| `UNKNOWN_FIELDS` | `400` | `"Unknown field(s): foo, bar."` | Champs non reconnus dans le body |
| `ID_MISMATCH` | `400` | `"The ID in the request body does not match the URL parameter."` | ID body ≠ ID URL |
| `INVALID_PAGINATION` | `400` | `"Invalid pagination parameters."` | page/limit invalides |
| `INVALID_THEME` | `400` | `"The provided theme_id does not reference an existing theme."` | theme_id inexistant (POST/PUT/PATCH) |
| `INVALID_FILTER` | `400` | `"Invalid filter parameters."` | Filtres invalides (type, theme_id, plages numériques incohérentes, etc.) |
| `TYPE_CHANGE_NOT_ALLOWED` | `400` | `"The question type cannot be changed."` | Tentative de changement de type via PUT ou PATCH |
| `UNAUTHORIZED` | `401` | `"Authentication token is missing or invalid."` | Token absent/expiré/invalide |
| `FORBIDDEN` | `403` | `"You do not have permission to perform this action."` | Rôle insuffisant |
| `NOT_FOUND` | `404` | `"The requested question was not found."` | Ressource inexistante |
| `METHOD_NOT_ALLOWED` | `405` | _(dynamique : ex. `"HTTP method DELETE is not allowed on this resource."`)_ | Méthode non supportée (message dynamique) |
| `QUESTION_ALREADY_EXISTS` | `409` | `"A question with this title already exists."` | Doublon de titre |
| `THEME_HAS_QUESTIONS` | `409` | `"Cannot delete this theme: questions are still associated with it."` | Suppression d'un thème avec questions liées (garde US-003 CA-30) |
| `UNSUPPORTED_MEDIA_TYPE` | `415` | `"Content-Type must be 'application/json'."` | Content-Type incorrect |
| `RATE_LIMIT_EXCEEDED` | `429` | `"Too many requests. Please retry in 30 seconds."` | Dépassement rate limit (header `Retry-After: 30`) |
| `INTERNAL_SERVER_ERROR` | `500` | `"An unexpected error occurred. Please try again later."` | Erreur serveur (aucun détail technique exposé) |

### Format standard des réponses d'erreur

```json
{
  "status": 400,
  "error": "VALIDATION_ERROR",
  "message": "Question title must start with an uppercase letter."
}
```

---

## 📐 Périmètre

| Inclus | Exclu |
|---|---|
| CRUD complet des questions (POST, GET, GET list, PUT, PATCH, DELETE) | Upload et gestion des fichiers médias (US dédiée) |
| Validation et normalisation du titre | Interface Angular de gestion des questions |
| Validation des choices, correct_answer, level, time_limit, points | Recherche full-text dans les questions |
| Cohérence type/champs (MCQ vs SPEED) | Vérification de dépendances à la suppression (parties en cours) |
| Pagination et filtrage combiné de la liste | Déploiement / CI-CD |
| Modification partielle via PATCH (JSON Merge Patch RFC 7396) | |
| Garde de suppression des thèmes (implémentation TODO CA-30 US-003) | |
| Création de la table `T_QUESTION_QST` dans le schéma de la base | |
| Champs `image_path` et `audio_path` (null par défaut, modifiables via PATCH) | |
| Gestion complète des erreurs | |
| Réutilisation des middlewares `authenticate` et `authorize` | |
| Rate limiting (100 req/min) | |
| Tests unitaires et d'intégration (couverture ≥ 90%) | |

---

## 🔍 Points de vigilance

### Unicité insensible à la casse du titre

L'unicité du titre repose sur `COLLATE NOCASE` dans SQLite. La contrainte `UNIQUE` de la table gère nativement ce cas. Côté application, la vérification d'unicité avant insertion/mise à jour doit également être insensible à la casse pour fournir un message d'erreur clair (`409`) plutôt qu'une erreur SQL brute.

### Cohérence type / champs conditionnels

Le champ `choices` (4 colonnes en base) n'a de sens que pour les questions MCQ. Pour les questions SPEED, ces colonnes doivent rester à `NULL`. L'API ne doit **jamais** retourner le champ `choices` dans la réponse JSON d'une question SPEED. Inversement, une question MCQ doit toujours retourner `choices` sous forme de tableau de 4 chaînes.

### Validation croisée correct_answer / choices

Pour les questions MCQ, le `correct_answer` doit correspondre exactement (insensible à la casse) à l'un des 4 `choices`. Cette validation s'applique :
- Au **POST** : `correct_answer` doit être dans `choices`.
- Au **PUT** : `correct_answer` doit être dans les nouveaux `choices`.
- Au **PATCH** : si `correct_answer` et/ou `choices` sont modifiés, la validation croisée s'effectue sur l'état **résultant** (fusion des anciennes et nouvelles valeurs).

### Immutabilité du type

Le champ `type` ne peut pas être modifié après la création, ni par PUT ni par PATCH. En PUT, le `type` doit être fourni mais doit correspondre au type actuel. En PATCH, le `type` ne doit pas être présent dans le body.

### PUT/PATCH sans changement réel

Lorsqu'un `PUT` ou `PATCH` est effectué avec des données identiques à l'existant, la colonne `QST_LAST_UPDATED_AT` ne doit **pas** être mise à jour. Le serveur doit comparer l'état normalisé entrant avec l'état stocké avant de décider de mettre à jour l'horodatage.

### PATCH — Sémantique JSON Merge Patch (RFC 7396)

- Champ **absent** du body → non modifié.
- Champ à **`null`** → suppression de la valeur (uniquement pour `image_path` et `audio_path` qui sont nullables ; pour les champs obligatoires → `400 VALIDATION_ERROR`).
- Body vide `{}` → aucune modification, retour `200 OK` avec la question inchangée.

### Intégrité référentielle — FK vers T_THEME_THM

Le champ `QST_THEME_ID` est une clé étrangère vers `T_THEME_THM.THM_ID`. La vérification de l'existence du thème doit être effectuée côté application (avant insertion/mise à jour) pour retourner un message d'erreur métier explicite (`400 INVALID_THEME`) plutôt qu'une erreur SQL de contrainte FK.

### Garde de suppression des thèmes

L'implémentation du TODO CA-30 de l'US-003 consiste à vérifier, avant toute suppression d'un thème, s'il existe des questions associées via une requête `SELECT COUNT(*) FROM T_QUESTION_QST WHERE QST_THEME_ID = ?`. Si le compteur est > 0, la suppression est refusée avec une erreur `409 THEME_HAS_QUESTIONS`.

### Cohérence UUIDv7 et horodatage

L'UUIDv7 et le `created_at` étant tous deux générés côté Node.js, il est recommandé de les générer au même instant pour garantir la cohérence entre le timestamp intégré dans l'UUIDv7 et la valeur de `created_at`.

### Sécurité des erreurs 500

Les erreurs internes ne doivent jamais exposer de détails techniques (stack trace, message SQL, etc.) dans la réponse API. Ces informations doivent être consignées uniquement dans les logs serveur.

### Filtrage — Validation stricte

Tous les paramètres de filtrage doivent être validés avant l'exécution de la requête SQL. Les paramètres inconnus dans la query string doivent être **ignorés silencieusement** (seuls les paramètres de filtrage documentés et `page`/`limit` sont reconnus). Un `theme_id` doit être un UUID valide et référencer un thème existant. Les valeurs numériques doivent être des entiers dans les plages autorisées. Un filtre exact et un filtre par plage sur le même champ sont mutuellement exclusifs.
