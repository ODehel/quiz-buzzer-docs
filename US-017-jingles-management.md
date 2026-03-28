# US-017 — Gestion des jingles et sons personnalisés

## 📋 Contexte projet

Voir [VISION.md](VISION.md) pour la description complète du projet et de ses quatre applications.

---

## 🎯 User Story

> **En tant que** maître du jeu,
> **je veux** uploader des jingles sur le serveur et les diffuser vers un ou plusieurs buzzers ciblés,
> **afin d'** animer la partie avec des sons personnalisés joués directement sur les buzzers.

---

## ✅ Critères d'acceptance

> 🧪 **Exigence de couverture** — Voir [Conventions techniques — Couverture des tests](CONVENTIONS-TECHNIQUES.md#-exigence-de-couverture-des-tests). Chaque CA doit être couvert par au moins un test automatisé. Couverture globale ≥ 90 %.

### Upload d'un jingle — `POST /api/v1/sounds`

| # | Critère | Résultat attendu |
|---|---|---|
| CA-1 | Upload d'un fichier audio valide (mp3, wav, ogg) avec un nom valide | `201 Created` avec la ressource créée (id, name, filename, url, created_at) |
| CA-2 | Le fichier est nommé `<sound_uuid>.<ext>` sur le disque | Pas de collision entre jingles |
| CA-3 | Le champ `name` est normalisé (trim + collapse des espaces) avant stockage | `"  Générique   intro  "` → `"Générique intro"` |
| CA-4 | Le champ `name` doit être non vide, entre 1 et 100 caractères après normalisation | Sinon → `400 VALIDATION_ERROR` |
| CA-5 | Le champ `file` est absent du multipart | `400 VALIDATION_ERROR` |
| CA-6 | Le champ `name` est absent du multipart | `400 VALIDATION_ERROR` |
| CA-7 | Le type MIME du fichier n'est pas dans la liste des types audio acceptés (`audio/mpeg`, `audio/wav`, `audio/ogg`) | `400 INVALID_MEDIA_TYPE` |
| CA-8 | Le fichier dépasse la taille maximale autorisée (10 Mo) | `413 FILE_TOO_LARGE` |
| CA-9 | Un jingle avec le même `name` (insensible à la casse) existe déjà | `409 SOUND_ALREADY_EXISTS` |
| CA-10 | Le `Content-Type` de la requête n'est pas `multipart/form-data` | `415 UNSUPPORTED_MEDIA_TYPE` |

### Lecture de la liste — `GET /api/v1/sounds`

| # | Critère | Résultat attendu |
|---|---|---|
| CA-11 | Récupérer la liste paginée des jingles | `200 OK` avec tableau paginé (id, name, filename, url, created_at) |
| CA-12 | Paramètres de pagination par défaut | `page=1`, `limit=20` |
| CA-13 | Paramètres `page` ou `limit` invalides (négatifs, zéro, non numériques, limit > 100) | `400 INVALID_PAGINATION` |
| CA-14 | Aucun jingle en base | `200 OK` avec `data: []`, `total: 0` |

### Lecture d'un jingle — `GET /api/v1/sounds/:id`

| # | Critère | Résultat attendu |
|---|---|---|
| CA-15 | Récupérer un jingle par son ID | `200 OK` avec la ressource complète |
| CA-16 | ID inexistant | `404 NOT_FOUND` |
| CA-17 | ID mal formé | `400 INVALID_UUID` |

### Suppression d'un jingle — `DELETE /api/v1/sounds/:id`

| # | Critère | Résultat attendu |
|---|---|---|
| CA-18 | Supprimer un jingle existant | `204 No Content` — fichier physique supprimé, entrée supprimée en base |
| CA-19 | ID inexistant | `404 NOT_FOUND` |
| CA-20 | ID mal formé | `400 INVALID_UUID` |
| CA-21 | Échec de la suppression physique du fichier (fichier absent du disque) | `204 No Content` — l'entrée en base est supprimée, un log `WARN` est émis |

### Diffusion d'un jingle — message WebSocket `play_sound`

| # | Critère | Résultat attendu |
|---|---|---|
| CA-22 | Angular envoie `play_sound` avec un `sound_id` valide et une liste de `targets` non vide | Le serveur envoie `play_sound_url` à chaque buzzer ciblé connecté |
| CA-23 | Angular envoie `play_sound` avec `targets: []` ou `targets` absent | Broadcast à tous les buzzers connectés |
| CA-24 | Un `username` dans `targets` ne correspond à aucun buzzer connecté | Le buzzer absent est ignoré silencieusement — log `WARN SOUND_TARGET_NOT_CONNECTED` |
| CA-25 | Le `sound_id` ne correspond à aucun jingle en base | Le serveur envoie `error` à Angular avec le code `SOUND_NOT_FOUND` |
| CA-26 | Le message `play_sound` est envoyé par un client avec le rôle `buzzer` | Ignoré silencieusement — log `WARN` |
| CA-27 | Le message `play_sound` est envoyé par un client non authentifié | Ignoré silencieusement — log `WARN` |
| CA-28 | `play_sound` reçu avec des champs manquants ou invalides (`sound_id` absent, format incorrect) | Le serveur envoie `error` à Angular avec le code `INVALID_MESSAGE` |
| CA-29 | Le buzzer ciblé reçoit le message `play_sound_url` avec l'URL HTTP du fichier | Le buzzer effectue une requête HTTP GET pour récupérer et jouer le fichier |
| CA-30 | Aucun buzzer connecté au moment du broadcast | Le serveur traite la diffusion sans erreur, log `INFO SOUND_NO_TARGETS` |

### Sécurité et transversalité

Voir [Annexe — Critères de sécurité transversaux](SECURITE-TRANSVERSALE.md)

| # | Critère | Résultat attendu |
|---|---|---|
| CA-31 | Bearer token sur les routes REST (voir annexe CA-Bearer) | Token absent/invalide/expiré → `401 UNAUTHORIZED` |
| CA-32 | Rôle administrateur sur les routes REST (voir annexe CA-Forbidden) | Rôle insuffisant → `403 FORBIDDEN` |
| CA-33 | Rate limiting REST (voir annexe CA-RateLimit) | Dépassement → `429 RATE_LIMIT_EXCEEDED` avec header `Retry-After: 60` |
| CA-34 | Méthode HTTP non supportée (voir annexe CA-MethodNotAllowed) | `405 METHOD_NOT_ALLOWED` avec header `Allow` adapté |
| CA-35 | Erreur serveur (voir annexe CA-InternalError) | `500 INTERNAL_SERVER_ERROR` sans détails techniques |
| CA-36 | Tests unitaires et d'intégration | Couverture de tests ≥ 90% |

---

## 🔄 Diagramme de flux

![Diagramme de flux — US-017 — Gestion des jingles et sons personnalisés](diagrams/US-017-jingles-management.png)

---

## 🔀 Diagramme de séquences

![Diagramme de séquences — US-017 — Gestion des jingles et sons personnalisés](diagrams/US-017-jingles-management-sequence.png)

---

## 🧪 Cas de tests — requêtes cURL

> **Variables** à définir avant d'exécuter les commandes :
> ```bash
> BASE_URL=http://localhost:3000
> TOKEN=<votre_token_JWT_admin>   # Obtenu via POST /api/v1/token (US-002)
> SOUND_ID=<uuid_jingle_créé>     # UUID retourné après un POST /api/v1/sounds réussi
> ```

### Upload d'un jingle — `POST /api/v1/sounds`

**CA-1** — Upload valide → `201 Created`

```bash
curl -s -w "\n→ HTTP %{http_code}\n" -X POST "$BASE_URL/api/v1/sounds" \
  -H "Authorization: Bearer $TOKEN" \
  -F "name=Générique intro" \
  -F "file=@/chemin/vers/jingle.mp3"
```

**CA-5** — Champ `file` absent → `400 VALIDATION_ERROR`

```bash
curl -s -w "\n→ HTTP %{http_code}\n" -X POST "$BASE_URL/api/v1/sounds" \
  -H "Authorization: Bearer $TOKEN" \
  -F "name=Générique intro"
```

**CA-6** — Champ `name` absent → `400 VALIDATION_ERROR`

```bash
curl -s -w "\n→ HTTP %{http_code}\n" -X POST "$BASE_URL/api/v1/sounds" \
  -H "Authorization: Bearer $TOKEN" \
  -F "file=@/chemin/vers/jingle.mp3"
```

**CA-7** — MIME non autorisé → `400 INVALID_MEDIA_TYPE`

```bash
curl -s -w "\n→ HTTP %{http_code}\n" -X POST "$BASE_URL/api/v1/sounds" \
  -H "Authorization: Bearer $TOKEN" \
  -F "name=Test MIME invalide" \
  -F "file=@/chemin/vers/image.jpg"
```

**CA-8** — Fichier > 10 Mo → `413 FILE_TOO_LARGE`

```bash
dd if=/dev/zero bs=1M count=11 > /tmp/big_audio.mp3
curl -s -w "\n→ HTTP %{http_code}\n" -X POST "$BASE_URL/api/v1/sounds" \
  -H "Authorization: Bearer $TOKEN" \
  -F "name=Fichier trop lourd" \
  -F "file=@/tmp/big_audio.mp3"
```

**CA-9** — Nom déjà existant → `409 SOUND_ALREADY_EXISTS`

```bash
# Exécuter après un premier upload réussi avec le même nom
curl -s -w "\n→ HTTP %{http_code}\n" -X POST "$BASE_URL/api/v1/sounds" \
  -H "Authorization: Bearer $TOKEN" \
  -F "name=Générique intro" \
  -F "file=@/chemin/vers/autre_jingle.mp3"
```

### Lecture de la liste — `GET /api/v1/sounds`

**CA-11** — Liste paginée → `200 OK`

```bash
curl -s -w "\n→ HTTP %{http_code}\n" -X GET "$BASE_URL/api/v1/sounds" \
  -H "Authorization: Bearer $TOKEN"
```

**CA-13** — Pagination invalide → `400 INVALID_PAGINATION`

```bash
curl -s -w "\n→ HTTP %{http_code}\n" -X GET "$BASE_URL/api/v1/sounds?page=0&limit=200" \
  -H "Authorization: Bearer $TOKEN"
```

### Lecture d'un jingle — `GET /api/v1/sounds/:id`

**CA-15** — Récupérer un jingle par ID → `200 OK`

```bash
curl -s -w "\n→ HTTP %{http_code}\n" -X GET "$BASE_URL/api/v1/sounds/$SOUND_ID" \
  -H "Authorization: Bearer $TOKEN"
```

**CA-16** — ID inexistant → `404 NOT_FOUND`

```bash
curl -s -w "\n→ HTTP %{http_code}\n" -X GET "$BASE_URL/api/v1/sounds/018e4f5a-0000-0000-0000-000000000000" \
  -H "Authorization: Bearer $TOKEN"
```

### Suppression d'un jingle — `DELETE /api/v1/sounds/:id`

**CA-18** — Suppression réussie → `204 No Content`

```bash
curl -s -w "\n→ HTTP %{http_code}\n" -X DELETE "$BASE_URL/api/v1/sounds/$SOUND_ID" \
  -H "Authorization: Bearer $TOKEN"
```

**CA-19** — ID inexistant → `404 NOT_FOUND`

```bash
curl -s -w "\n→ HTTP %{http_code}\n" -X DELETE "$BASE_URL/api/v1/sounds/018e4f5a-0000-0000-0000-000000000000" \
  -H "Authorization: Bearer $TOKEN"
```

---

## 🔧 Spécifications techniques

Voir les [Conventions techniques](CONVENTIONS-TECHNIQUES.md) pour la stack complète, les principes d'architecture (KISS, DRY, YAGNI, SOLID) et les conventions de données.

### Schéma de la table

```sql
CREATE TABLE IF NOT EXISTS T_SOUND_SND
(
    SND_ID         TEXT PRIMARY KEY,
    SND_NAME       TEXT NOT NULL UNIQUE COLLATE NOCASE,
    SND_FILENAME   TEXT NOT NULL UNIQUE,
    SND_CREATED_AT TEXT NOT NULL
);
```

### Stockage des fichiers

```
uploads/
  sounds/
    <sound_uuid>.mp3   # ex. : 018e4f5a-8c3b-7d2e-9f1a-4b5c6d7e8f9a.mp3
    <sound_uuid>.wav
    <sound_uuid>.ogg
```

Le répertoire `uploads/sounds/` est créé automatiquement au démarrage du serveur s'il n'existe pas.

### Types MIME acceptés

| MIME | Extension |
|---|---|
| `audio/mpeg` | `.mp3` |
| `audio/wav` | `.wav` |
| `audio/ogg` | `.ogg` |

### Taille maximale

| Limite | Valeur |
|---|---|
| Taille maximale par fichier | 10 Mo |

### Format JSON — Réponse `POST` (création)

```json
{
  "id": "018e4f5a-8c3b-7d2e-9f1a-4b5c6d7e8f9a",
  "name": "Générique intro",
  "filename": "018e4f5a-8c3b-7d2e-9f1a-4b5c6d7e8f9a.mp3",
  "url": "/uploads/sounds/018e4f5a-8c3b-7d2e-9f1a-4b5c6d7e8f9a.mp3",
  "created_at": "2026-03-27T10:00:00.000Z"
}
```

### Format JSON — Réponse `GET` liste paginée

```json
{
  "data": [
    {
      "id": "018e4f5a-8c3b-7d2e-9f1a-4b5c6d7e8f9a",
      "name": "Générique intro",
      "filename": "018e4f5a-8c3b-7d2e-9f1a-4b5c6d7e8f9a.mp3",
      "url": "/uploads/sounds/018e4f5a-8c3b-7d2e-9f1a-4b5c6d7e8f9a.mp3",
      "created_at": "2026-03-27T10:00:00.000Z"
    }
  ],
  "page": 1,
  "limit": 20,
  "total": 1,
  "total_pages": 1
}
```

### Format des messages WebSocket

**Déclenchement — Angular → Serveur**

```json
{
  "type": "play_sound",
  "sound_id": "018e4f5a-8c3b-7d2e-9f1a-4b5c6d7e8f9a",
  "targets": ["quiz_buzzer_01", "quiz_buzzer_03"]
}
```

> `targets` est optionnel. Absent ou tableau vide → broadcast à tous les buzzers connectés.

**Diffusion — Serveur → Buzzer(s) ciblé(s)**

```json
{
  "type": "play_sound_url",
  "sound_id": "018e4f5a-8c3b-7d2e-9f1a-4b5c6d7e8f9a",
  "url": "http://192.168.1.10:3000/uploads/sounds/018e4f5a-8c3b-7d2e-9f1a-4b5c6d7e8f9a.mp3"
}
```

> L'URL est **absolue** (schéma + hôte + port) pour permettre à l'ESP32 d'effectuer une requête HTTP GET autonome sans connaître l'adresse du serveur à l'avance.

**Erreur — Serveur → Angular**

```json
{
  "type": "error",
  "code": "SOUND_NOT_FOUND",
  "message": "The requested sound was not found."
}
```

```json
{
  "type": "error",
  "code": "INVALID_MESSAGE",
  "message": "Missing or invalid field: sound_id."
}
```

### Résolution de l'URL absolue

Le serveur construit l'URL absolue à partir de la variable d'environnement `SERVER_BASE_URL` (ex. : `http://192.168.1.10:3000`). Cette variable est définie dans le fichier `.env` et doit être renseignée lors du déploiement.

```
SERVER_BASE_URL=http://192.168.1.10:3000
```

---

## 📡 Endpoints

| Méthode | URL | Description | Auth | Code succès |
|---|---|---|---|---|
| `POST` | `/api/v1/sounds` | Uploader un jingle | Bearer (admin) | `201 Created` |
| `GET` | `/api/v1/sounds` | Lister les jingles (paginé) | Bearer (admin) | `200 OK` |
| `GET` | `/api/v1/sounds/:id` | Récupérer un jingle | Bearer (admin) | `200 OK` |
| `DELETE` | `/api/v1/sounds/:id` | Supprimer un jingle | Bearer (admin) | `204 No Content` |

### Headers `Allow` par ressource

| URL | Méthodes autorisées |
|---|---|
| `/api/v1/sounds` | `GET, POST` |
| `/api/v1/sounds/:id` | `GET, DELETE` |

---

## 🔐 Authentification et autorisation

Voir l'[Annexe — Authentification et autorisation](AUTHENTIFICATION.md) pour le mécanisme JWT, la structure du payload et l'architecture middleware.

Les middlewares `authenticate` et `authorize('admin')` définis en [US-003](US-003-authentication-token.md) sont réutilisés sur toutes les routes de cette US.

---

## 📝 Logging structuré

| Événement | Niveau | Champs notables |
|---|---|---|
| `SOUND_UPLOADED` | `INFO` | `sound_id`, `name`, `filename`, `size_bytes` |
| `SOUND_DELETED` | `INFO` | `sound_id`, `name`, `filename` |
| `SOUND_DELETE_FILE_ERROR` | `WARN` | `sound_id`, `filename`, `error` — fichier physique introuvable lors de la suppression |
| `SOUND_PLAYED` | `INFO` | `sound_id`, `targets_requested`, `targets_reached` |
| `SOUND_TARGET_NOT_CONNECTED` | `WARN` | `sound_id`, `username` — buzzer ciblé mais non connecté |
| `SOUND_NO_TARGETS` | `INFO` | `sound_id` — aucun buzzer connecté lors d'un broadcast |

---

## 🚨 Catalogue des erreurs

### Codes standards
Voir le [Catalogue centralisé des codes d'erreur](error-codes.md#1️⃣-codes-derreur-standards-transversaux)

### Codes spécifiques à cette US

| Code erreur | Code HTTP | Message | Contexte |
|---|---|---|---|
| `SOUND_ALREADY_EXISTS` | `409` | `"A sound with this name already exists."` | Doublon de nom (insensible à la casse) |
| `INVALID_MEDIA_TYPE` | `400` | `"File MIME type is not allowed for the declared media type."` | MIME non autorisé — réutilisé depuis US-016 |
| `FILE_TOO_LARGE` | `413` | `"File size exceeds the 10MB limit."` | Fichier dépassant 10 Mo — réutilisé depuis US-016 |
| `SOUND_NOT_FOUND` | — | `"The requested sound was not found."` | Erreur WebSocket uniquement — `sound_id` inconnu lors d'un `play_sound` |

---

## 📐 Périmètre

| Inclus | Exclu |
|---|---|
| CRUD partiel jingles : POST, GET liste, GET par ID, DELETE | Modification d'un jingle (PUT/PATCH) — YAGNI |
| Validation nom (normalisation, unicité insensible à la casse) | Interface Angular |
| Validation MIME et taille (réutilisation US-016) | Transcodage / normalisation audio |
| Stockage sur le serveur avec URL relative en base | Streaming audio direct via WebSocket |
| Diffusion WebSocket `play_sound` vers buzzers ciblés ou broadcast | Confirmation de lecture côté buzzer |
| Résolution de l'URL absolue via `SERVER_BASE_URL` | Persistance de l'historique des diffusions |
| Pagination de la liste (défaut : page=1, limit=20, max 100) | Déploiement / CI-CD |
| Logging structuré des opérations REST et WebSocket | |
| Tests unitaires et d'intégration (couverture ≥ 90%) | |

---

## 🔍 Points de vigilance

### Unicité insensible à la casse du nom

La contrainte `UNIQUE COLLATE NOCASE` sur `SND_NAME` garantit qu'on ne peut pas avoir deux jingles nommés `"Générique"` et `"générique"`. La vérification applicative préalable à l'insertion permet de retourner un `409 SOUND_ALREADY_EXISTS` explicite plutôt qu'une erreur SQLite brute.

### Suppression physique tolérante aux incohérences

Si le fichier physique est absent lors d'une suppression (incohérence base/disque), l'entrée en base est supprimée quand même et un log `WARN SOUND_DELETE_FILE_ERROR` est émis. Cette tolérance évite qu'un jingle devienne indélébile suite à une suppression manuelle accidentelle du fichier.

### Résolution des targets par username

Les `targets` du message `play_sound` sont des **usernames** de buzzers (ex. `"quiz_buzzer_01"`), cohérents avec le champ `username` du registre de connexions défini en US-009. Le serveur itère sur le registre pour retrouver les connexions WebSocket actives correspondantes.

### URL absolue obligatoire pour l'ESP32

L'ESP32-S3 effectue une requête HTTP GET autonome pour récupérer le fichier audio. Il a besoin d'une URL absolue complète (schéma + hôte + port). L'URL relative stockée en base (`/uploads/sounds/...`) est enrichie au moment de la diffusion WebSocket en préfixant `SERVER_BASE_URL`. Cette variable doit correspondre à l'adresse IP locale du serveur sur le réseau WiFi partagé.

### Réutilisation du module `multer` (DRY)

La configuration `multer` introduite en US-016 (fileFilter MIME, limite de taille, module `src/middlewares/upload.js`) est réutilisée directement pour l'upload des jingles, en paramétrant uniquement le répertoire de destination (`uploads/sounds/`). Aucune logique de validation de fichier n'est dupliquée.

