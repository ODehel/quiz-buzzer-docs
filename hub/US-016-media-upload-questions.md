# US-016 — Upload et gestion des fichiers médias des questions

## 📋 Contexte projet

Voir [VISION.md](../shared/VISION.md) pour la description complète du projet et de ses quatre applications.

---

## 🎯 User Story

> **En tant qu'** administrateur,
> **je veux** uploader et supprimer les fichiers image et audio associés à une question,
> **afin d'** enrichir l'expérience visuelle et sonore du quiz lors de l'affichage des questions.

---

## ✅ Critères d'acceptance

> 🧪 **Exigence de couverture** — Voir [Conventions techniques — Couverture des tests](../shared/CONVENTIONS-TECHNIQUES.md#-exigence-de-couverture-des-tests). Chaque CA doit être couvert par au moins un test automatisé. Couverture globale ≥ 90 %.

### Upload d'un média — `POST /api/v1/questions/:id/media`

| # | Critère | Résultat attendu |
|---|---|---|
| CA-1 | Upload d'une image valide (jpeg, png, gif, webp) sur une question existante | `200 OK` — `image_path` mis à jour en base, chemin relatif retourné dans la réponse |
| CA-2 | Upload d'un audio valide (mp3, wav, ogg) sur une question existante | `200 OK` — `audio_path` mis à jour en base, chemin relatif retourné dans la réponse |
| CA-3 | Upload d'une image alors qu'une image existe déjà | L'ancien fichier est supprimé physiquement, le nouveau le remplace, `image_path` mis à jour — `200 OK` |
| CA-4 | Upload d'un audio alors qu'un audio existe déjà | L'ancien fichier est supprimé physiquement, le nouveau le remplace, `audio_path` mis à jour — `200 OK` |
| CA-5 | Le fichier uploadé est nommé `<question_uuid>-<type>.<extension>` côté serveur | Pas de collision de noms entre questions |
| CA-6 | Le champ `file` est absent du multipart | `400 VALIDATION_ERROR` |
| CA-7 | Le champ `type` est absent du multipart | `400 VALIDATION_ERROR` |
| CA-8 | Le champ `type` contient une valeur autre que `image` ou `audio` | `400 VALIDATION_ERROR` |
| CA-9 | Le type MIME du fichier ne correspond pas au `type` déclaré (ex. : `type=image` avec un fichier mp3) | `400 INVALID_MEDIA_TYPE` |
| CA-10 | Le type MIME du fichier n'est pas dans la liste des types acceptés | `400 INVALID_MEDIA_TYPE` |
| CA-11 | Le fichier dépasse la taille maximale autorisée (10 Mo) | `413 FILE_TOO_LARGE` |
| CA-12 | L'ID de la question est inexistant | `404 NOT_FOUND` |
| CA-13 | L'ID de la question est mal formé | `400 INVALID_UUID` |
| CA-14 | Le `Content-Type` de la requête n'est pas `multipart/form-data` | `415 UNSUPPORTED_MEDIA_TYPE` |

### Suppression d'un média — `DELETE /api/v1/questions/:id/media/:type`

| # | Critère | Résultat attendu |
|---|---|---|
| CA-15 | Suppression de l'image d'une question qui en possède une | `204 No Content` — fichier supprimé physiquement, `image_path` remis à `null` en base |
| CA-16 | Suppression de l'audio d'une question qui en possède un | `204 No Content` — fichier supprimé physiquement, `audio_path` remis à `null` en base |
| CA-17 | Suppression de l'image d'une question qui n'en possède pas | `404 NOT_FOUND` |
| CA-18 | Suppression de l'audio d'une question qui n'en possède pas | `404 NOT_FOUND` |
| CA-19 | `:type` contient une valeur autre que `image` ou `audio` | `400 VALIDATION_ERROR` |
| CA-20 | L'ID de la question est inexistant | `404 NOT_FOUND` |
| CA-21 | L'ID de la question est mal formé | `400 INVALID_UUID` |

### Cohérence avec les endpoints existants

| # | Critère | Résultat attendu |
|---|---|---|
| CA-22 | Après un upload réussi, `GET /api/v1/questions/:id` retourne le champ `image_path` ou `audio_path` mis à jour | Cohérence avec US-005 |
| CA-23 | Après une suppression réussie, `GET /api/v1/questions/:id` retourne le champ correspondant à `null` | Cohérence avec US-005 |
| CA-24 | `PATCH /api/v1/questions/:id` avec `image_path: null` supprime le fichier physique si un fichier existe | Cohérence avec US-007 — la suppression physique est déléguée à la logique commune |

### Sécurité et transversalité

Voir [Annexe — Critères de sécurité transversaux](../shared/SECURITE-TRANSVERSALE.md)

| # | Critère | Résultat attendu |
|---|---|---|
| CA-25 | Bearer token (voir annexe CA-Bearer) | Token absent/invalide/expiré → `401 UNAUTHORIZED` |
| CA-26 | Rôle administrateur (voir annexe CA-Forbidden) | Rôle insuffisant → `403 FORBIDDEN` |
| CA-27 | Rate limiting (voir annexe CA-RateLimit) | Dépassement → `429 RATE_LIMIT_EXCEEDED` avec header `Retry-After: 60` |
| CA-28 | Méthode HTTP (voir annexe CA-MethodNotAllowed) | `405 METHOD_NOT_ALLOWED` avec header `Allow` adapté |
| CA-29 | Erreur serveur (voir annexe CA-InternalError) | `500 INTERNAL_SERVER_ERROR` sans détails techniques |
| CA-30 | Tests unitaires et d'intégration | Couverture de tests ≥ 90% |

---

## 🔄 Diagramme de flux

![Diagramme de flux — US-016 — Upload et gestion des fichiers médias des questions](diagrams/US-016-media-upload-questions.png)

---

## 🔀 Diagramme de séquences

![Diagramme de séquences — US-016 — Upload et gestion des fichiers médias des questions](diagrams/US-016-media-upload-questions-sequence.png)

---

## 🧪 Cas de tests — requêtes cURL

> **Variables** à définir avant d'exécuter les commandes :
> ```bash
> BASE_URL=http://localhost:3000
> TOKEN=<votre_token_JWT_admin>           # Obtenu via POST /api/v1/token (US-002)
> QUESTION_ID=<uuid_question_existante>   # UUID d'une question créée via US-005
> ```

### Upload d'un média — `POST /api/v1/questions/:id/media`

**CA-1** — Upload d'une image valide → `200 OK`

```bash
curl -s -w "\n→ HTTP %{http_code}\n" -X POST "$BASE_URL/api/v1/questions/$QUESTION_ID/media" \
  -H "Authorization: Bearer $TOKEN" \
  -F "type=image" \
  -F "file=@/chemin/vers/image.jpg"
```

**CA-2** — Upload d'un audio valide → `200 OK`

```bash
curl -s -w "\n→ HTTP %{http_code}\n" -X POST "$BASE_URL/api/v1/questions/$QUESTION_ID/media" \
  -H "Authorization: Bearer $TOKEN" \
  -F "type=audio" \
  -F "file=@/chemin/vers/audio.mp3"
```

**CA-6** — Champ `file` absent → `400 VALIDATION_ERROR`

```bash
curl -s -w "\n→ HTTP %{http_code}\n" -X POST "$BASE_URL/api/v1/questions/$QUESTION_ID/media" \
  -H "Authorization: Bearer $TOKEN" \
  -F "type=image"
```

**CA-7** — Champ `type` absent → `400 VALIDATION_ERROR`

```bash
curl -s -w "\n→ HTTP %{http_code}\n" -X POST "$BASE_URL/api/v1/questions/$QUESTION_ID/media" \
  -H "Authorization: Bearer $TOKEN" \
  -F "file=@/chemin/vers/image.jpg"
```

**CA-8** — Valeur `type` invalide → `400 VALIDATION_ERROR`

```bash
curl -s -w "\n→ HTTP %{http_code}\n" -X POST "$BASE_URL/api/v1/questions/$QUESTION_ID/media" \
  -H "Authorization: Bearer $TOKEN" \
  -F "type=video" \
  -F "file=@/chemin/vers/video.mp4"
```

**CA-9** — MIME incompatible avec le type déclaré → `400 INVALID_MEDIA_TYPE`

```bash
curl -s -w "\n→ HTTP %{http_code}\n" -X POST "$BASE_URL/api/v1/questions/$QUESTION_ID/media" \
  -H "Authorization: Bearer $TOKEN" \
  -F "type=image" \
  -F "file=@/chemin/vers/audio.mp3"
```

**CA-11** — Fichier > 10 Mo → `413 FILE_TOO_LARGE`

```bash
# Générer un fichier de 11 Mo pour le test
dd if=/dev/zero bs=1M count=11 | gzip > /tmp/big_file.jpg
curl -s -w "\n→ HTTP %{http_code}\n" -X POST "$BASE_URL/api/v1/questions/$QUESTION_ID/media" \
  -H "Authorization: Bearer $TOKEN" \
  -F "type=image" \
  -F "file=@/tmp/big_file.jpg"
```

**CA-12** — Question inexistante → `404 NOT_FOUND`

```bash
curl -s -w "\n→ HTTP %{http_code}\n" -X POST "$BASE_URL/api/v1/questions/018e4f5a-0000-0000-0000-000000000000/media" \
  -H "Authorization: Bearer $TOKEN" \
  -F "type=image" \
  -F "file=@/chemin/vers/image.jpg"
```

### Suppression d'un média — `DELETE /api/v1/questions/:id/media/:type`

**CA-15** — Suppression d'une image existante → `204 No Content`

```bash
curl -s -w "\n→ HTTP %{http_code}\n" -X DELETE "$BASE_URL/api/v1/questions/$QUESTION_ID/media/image" \
  -H "Authorization: Bearer $TOKEN"
```

**CA-16** — Suppression d'un audio existant → `204 No Content`

```bash
curl -s -w "\n→ HTTP %{http_code}\n" -X DELETE "$BASE_URL/api/v1/questions/$QUESTION_ID/media/audio" \
  -H "Authorization: Bearer $TOKEN"
```

**CA-17** — Suppression d'une image absente → `404 NOT_FOUND`

```bash
# Exécuter après CA-15 (image déjà supprimée)
curl -s -w "\n→ HTTP %{http_code}\n" -X DELETE "$BASE_URL/api/v1/questions/$QUESTION_ID/media/image" \
  -H "Authorization: Bearer $TOKEN"
```

**CA-19** — `:type` invalide → `400 VALIDATION_ERROR`

```bash
curl -s -w "\n→ HTTP %{http_code}\n" -X DELETE "$BASE_URL/api/v1/questions/$QUESTION_ID/media/video" \
  -H "Authorization: Bearer $TOKEN"
```

---

## 🔧 Spécifications techniques

Voir les [Conventions techniques](../shared/CONVENTIONS-TECHNIQUES.md) pour la stack complète, les principes d'architecture (KISS, DRY, YAGNI, SOLID) et les conventions de données.

### Pas de modification de schéma SQL

Cette US n'introduit aucune nouvelle table. Les colonnes `QST_IMAGE_PATH` et `QST_AUDIO_PATH` existent déjà dans `T_QUESTION_QST` (définie en US-005) avec une valeur par défaut `NULL`. Seule la mise à jour de ces colonnes via `UPDATE` est effectuée.

### Stockage des fichiers

```
uploads/
  questions/
    <question_uuid>-image.<ext>   # ex. : 018e4f5a-8c3b-7d2e-9f1a-4b5c6d7e8f9a-image.jpg
    <question_uuid>-audio.<ext>   # ex. : 018e4f5a-8c3b-7d2e-9f1a-4b5c6d7e8f9a-audio.mp3
```

Le répertoire `uploads/questions/` est créé automatiquement au démarrage du serveur s'il n'existe pas.

### Chemin retourné en réponse

Le chemin stocké en base et retourné dans la réponse est **relatif à la racine du serveur**, préfixé par `/uploads/questions/` :

```json
{
  "id": "018e4f5a-8c3b-7d2e-9f1a-4b5c6d7e8f9a",
  "image_path": "/uploads/questions/018e4f5a-8c3b-7d2e-9f1a-4b5c6d7e8f9a-image.jpg",
  "audio_path": null
}
```

### Types MIME acceptés

| Type déclaré | MIME acceptés |
|---|---|
| `image` | `image/jpeg`, `image/png`, `image/gif`, `image/webp` |
| `audio` | `audio/mpeg` (mp3), `audio/wav`, `audio/ogg` |

La vérification du MIME est effectuée par `multer` via le `fileFilter`, **pas** uniquement sur l'extension du nom de fichier.

### Taille maximale

| Limite | Valeur |
|---|---|
| Taille maximale par fichier | 10 Mo |

### Format JSON — Réponse `POST` (upload réussi)

```json
{
  "id": "018e4f5a-8c3b-7d2e-9f1a-4b5c6d7e8f9a",
  "image_path": "/uploads/questions/018e4f5a-8c3b-7d2e-9f1a-4b5c6d7e8f9a-image.jpg",
  "audio_path": null,
  "last_updated_at": "2026-03-27T10:00:00.000Z"
}
```

---

## 📡 Endpoints

| Méthode | URL | Description | Auth | Code succès |
|---|---|---|---|---|
| `POST` | `/api/v1/questions/:id/media` | Uploader un fichier image ou audio | Bearer (admin) | `200 OK` |
| `DELETE` | `/api/v1/questions/:id/media/:type` | Supprimer un fichier image ou audio | Bearer (admin) | `204 No Content` |

### Headers `Allow` par ressource

| URL | Méthodes autorisées |
|---|---|
| `/api/v1/questions/:id/media` | `POST` |
| `/api/v1/questions/:id/media/:type` | `DELETE` |

---

## 🔐 Authentification et autorisation

Voir l'[Annexe — Authentification et autorisation](../shared/AUTHENTIFICATION.md) pour le mécanisme JWT, la structure du payload et l'architecture middleware.

Les middlewares `authenticate` et `authorize('admin')` définis en [US-003](US-003-authentication-token.md) sont réutilisés sur toutes les routes de cette US.

---

## 📝 Logging structuré

| Événement | Niveau | Champs notables |
|---|---|---|
| `MEDIA_UPLOADED` | `INFO` | `question_id`, `media_type`, `filename`, `mime_type`, `size_bytes` |
| `MEDIA_REPLACED` | `INFO` | `question_id`, `media_type`, `old_filename`, `new_filename` |
| `MEDIA_DELETED` | `INFO` | `question_id`, `media_type`, `filename` |
| `MEDIA_DELETE_FILE_ERROR` | `WARN` | `question_id`, `media_type`, `filename`, `error` — fichier physique introuvable lors d'une suppression (incohérence base/disque) |

---

## 🚨 Catalogue des erreurs

### Codes standards
Voir le [Catalogue centralisé des codes d'erreur](error-codes.md#1️⃣-codes-derreur-standards-transversaux)

### Codes spécifiques à cette US

| Code erreur | Code HTTP | Message | Contexte |
|---|---|---|---|
| `INVALID_MEDIA_TYPE` | `400` | `"File MIME type is not allowed for the declared media type."` | MIME incompatible avec le `type` déclaré ou MIME non autorisé |
| `FILE_TOO_LARGE` | `413` | `"File size exceeds the 10MB limit."` | Fichier dépassant 10 Mo |

---

## 📐 Périmètre

| Inclus | Exclu |
|---|---|
| Upload image et audio via `multipart/form-data` | Interface Angular |
| Remplacement d'un fichier existant (suppression physique de l'ancien) | Redimensionnement / transcodage des fichiers |
| Suppression d'un fichier avec remise à `null` en base | Diffusion des fichiers aux buzzers (US-017) |
| Validation du type MIME et de la taille | Gestion des médias des jingles (US-017) |
| Convention de nommage sans collision (`<uuid>-<type>.<ext>`) | Déploiement / CI-CD |
| Cohérence avec `GET /api/v1/questions/:id` (US-005) et `PATCH` (US-007) | |
| Création automatique du répertoire `uploads/questions/` au démarrage | |
| Logging structuré des opérations de fichiers | |
| Tests unitaires et d'intégration (couverture ≥ 90%) | |

---

## 🔍 Points de vigilance

### Suppression physique lors d'un remplacement

Lorsqu'un fichier est uploadé et qu'un fichier du même type existe déjà pour cette question, l'ancien fichier doit être supprimé physiquement **avant** l'écriture en base. En cas d'échec de la suppression physique (fichier déjà absent), l'opération continue et un log `WARN` est émis — cette incohérence ne doit pas bloquer l'upload.

### Cohérence base / disque sur le `PATCH` existant (US-007)

Le handler `PATCH /api/v1/questions/:id` de l'US-007 accepte `image_path: null` et `audio_path: null` pour effacer les chemins. Depuis cette US-016, si un fichier physique est associé, la suppression du champ en base doit également déclencher la suppression physique du fichier. Cette logique doit être centralisée dans un service partagé (`MediaService`) pour éviter toute duplication (DRY).

### Validation MIME côté serveur obligatoire

La validation du type MIME ne doit pas reposer uniquement sur l'extension du fichier fourni par le client, qui peut être falsifiée. `multer` doit inspecter les octets magiques du fichier ou utiliser une bibliothèque de détection MIME côté serveur.

### Isolation du répertoire d'upload

Le répertoire `uploads/questions/` ne doit pas être accessible en écriture par d'autres processus que le serveur. Le serveur expose ce répertoire en lecture statique (`express.static`) pour permettre aux clients (Angular, buzzers) de récupérer les fichiers via leur chemin relatif.

