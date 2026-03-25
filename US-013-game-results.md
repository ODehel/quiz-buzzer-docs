# US-013 — Consultation des resultats d'une partie

## Contexte projet

Le projet **Quiz Buzzer** se decompose en quatre applications :

| Application | Technologie | Role |
|---|---|---|
| **Buzzers** | PlatformIO / ESP32-S3 | Peripheriques physiques de jeu |
| **App mobile** | Android / NFC | Configuration WiFi des buzzers |
| **App maitre de jeu** | Angular | Interface de gestion des parties |
| **Serveur (hub)** | Node.js / JavaScript | Communication WebSocket entre l'app Angular et les buzzers, gestion du workflow des parties |

---

## User Story

> **En tant qu'** administrateur,
> **je veux** consulter les resultats finaux d'une partie terminee via un endpoint REST,
> **afin de** pouvoir recuperer le classement final meme apres une deconnexion WebSocket ou un crash de l'application Angular.

---

## Motivation

Actuellement, les resultats sont diffuses question par question via WebSocket (`question_result` et `question_result_summary`). Si l'application Angular se reconnecte apres un crash, il n'existe aucun moyen REST de recuperer le classement final d'une partie terminee. Cet endpoint comble ce manque et assure la coherence avec l'architecture REST existante.

---

## Criteres d'acceptance

> Chaque critere d'acceptance liste ci-dessous doit etre couvert par **au moins un test automatise** (unitaire et/ou d'integration). La couverture globale du code de l'US doit etre **>= 90%**, mesuree via `jest --coverage`.

### Lecture des resultats — `GET /api/v1/games/:id/results`

| # | Critere | Resultat attendu |
|---|---|---|
| CA-1 | Recuperer les resultats d'une partie en statut `COMPLETED` | `200 OK` avec le classement final et le detail par question |
| CA-2 | La reponse contient `game_id`, `quiz_id`, `status`, `ranking` et `questions` | Tous les champs presents |
| CA-3 | Le classement (`ranking`) est trie par score decroissant, puis par temps cumule croissant en cas d'egalite | Le participant avec le score le plus eleve a le `rank` 1 ; a score egal, le plus rapide est classe devant |
| CA-4 | Chaque entree du classement contient `rank`, `order`, `name`, `score`, `total_time_ms` | Tous les champs presents |
| CA-5 | Le detail par question (`questions`) contient `question_id` et `answers` | Tous les champs presents |
| CA-6 | Chaque reponse contient `participant_order`, `answer`, `time_ms`, `points_earned`, `cumulative_score` | Tous les champs presents |
| CA-7 | Partie en statut autre que `COMPLETED` (ex: `PENDING`, `OPEN`) | `409 GAME_NOT_COMPLETED` |
| CA-8 | ID inexistant | `404 NOT_FOUND` |
| CA-9 | ID mal forme | `400 INVALID_UUID` |
| CA-10 | Partie terminee sans reponses (aucune question jouee) | `200 OK` avec classement a score 0 et `questions` vide |

### Securite et transversalite

Voir [Annexe — Criteres de securite transversaux](SECURITE-TRANSVERSALE.md)

Les criteres suivants s'appliquent a cette route :

| # | Critere | Resultat attendu |
|---|---|---|
| CA-11 | Bearer token (voir annexe CA-Bearer) | Token absent/invalide/expire -> `401 UNAUTHORIZED` |
| CA-12 | Role administrateur (voir annexe CA-Forbidden) | Role insuffisant -> `403 FORBIDDEN` |
| CA-13 | Rate limiting (voir annexe CA-RateLimit) | Depassement -> `429 RATE_LIMIT_EXCEEDED` avec header `Retry-After: 60` |
| CA-14 | Methode HTTP (voir annexe CA-MethodNotAllowed) | Seul `GET` est autorise -> `405 METHOD_NOT_ALLOWED` avec header `Allow: GET` |
| CA-15 | Erreur serveur (voir annexe CA-InternalError) | `500 INTERNAL_SERVER_ERROR` sans details techniques |
| CA-16 | Tests unitaires et d'integration | Couverture >= 90% |

---

## Endpoint

| Methode | URL | Description | Auth | Code succes |
|---|---|---|---|---|
| `GET` | `/api/v1/games/:id/results` | Recuperer les resultats finaux d'une partie terminee | Bearer (admin) | `200 OK` |

### Headers `Allow`

| URL | Methodes autorisees |
|---|---|
| `/api/v1/games/:id/results` | `GET` |

---

## Format JSON — Reponse `GET /api/v1/games/:id/results`

```json
{
  "game_id": "018e4f5d-0000-7000-8000-000000000001",
  "quiz_id": "018e4f5c-0000-7000-8000-000000000001",
  "status": "COMPLETED",
  "ranking": [
    { "rank": 1, "order": 1, "name": "Alice", "score": 20, "total_time_ms": 6000 },
    { "rank": 2, "order": 3, "name": "Charlie", "score": 15, "total_time_ms": 7600 },
    { "rank": 3, "order": 2, "name": "Bob", "score": 10, "total_time_ms": 11000 }
  ],
  "questions": [
    {
      "question_id": "018e4f5b-0000-7000-8000-000000000001",
      "answers": [
        {
          "participant_order": 1,
          "answer": "A",
          "time_ms": 3200,
          "points_earned": 10,
          "cumulative_score": 10
        },
        {
          "participant_order": 2,
          "answer": "B",
          "time_ms": 5000,
          "points_earned": 0,
          "cumulative_score": 0
        },
        {
          "participant_order": 3,
          "answer": "A",
          "time_ms": 4100,
          "points_earned": 10,
          "cumulative_score": 10
        }
      ]
    },
    {
      "question_id": "018e4f5b-0000-7000-8000-000000000002",
      "answers": [
        {
          "participant_order": 1,
          "answer": "C",
          "time_ms": 2800,
          "points_earned": 10,
          "cumulative_score": 20
        },
        {
          "participant_order": 2,
          "answer": "D",
          "time_ms": 6000,
          "points_earned": 10,
          "cumulative_score": 10
        },
        {
          "participant_order": 3,
          "answer": "B",
          "time_ms": 3500,
          "points_earned": 5,
          "cumulative_score": 15
        }
      ]
    }
  ]
}
```

---

## Cas de tests — requetes cURL

> **Variables** a definir avant d'executer les commandes :
> ```bash
> BASE_URL=http://localhost:3000
> TOKEN=<votre_token_JWT_admin>       # Obtenu via POST /api/v1/token (US-003)
> TOKEN_BUZZER=<token_JWT_buzzer>     # Token avec role buzzer (pour CA-12)
> GAME_ID=<uuid_partie_completed>    # UUID d'une partie en statut COMPLETED
> ```

### Lecture des resultats — `GET /api/v1/games/:id/results`

**CA-1** — Recuperer les resultats d'une partie terminee -> `200 OK`

```bash
curl -s -w "\n-> HTTP %{http_code}\n" -X GET "$BASE_URL/api/v1/games/$GAME_ID/results" \
  -H "Authorization: Bearer $TOKEN"
```

**CA-7** — Partie non terminee -> `409 GAME_NOT_COMPLETED`

```bash
# Prerequis : la partie est en statut PENDING ou OPEN
curl -s -w "\n-> HTTP %{http_code}\n" -X GET "$BASE_URL/api/v1/games/$GAME_ID/results" \
  -H "Authorization: Bearer $TOKEN"
# Attendu : {"status":409,"error":"GAME_NOT_COMPLETED","message":"Results are only available for completed games."}
```

**CA-8** — ID inexistant -> `404 NOT_FOUND`

```bash
curl -s -w "\n-> HTTP %{http_code}\n" -X GET "$BASE_URL/api/v1/games/018e4f5a-0000-7000-8000-000000000000/results" \
  -H "Authorization: Bearer $TOKEN"
```

**CA-9** — ID mal forme -> `400 INVALID_UUID`

```bash
curl -s -w "\n-> HTTP %{http_code}\n" -X GET "$BASE_URL/api/v1/games/not-a-uuid/results" \
  -H "Authorization: Bearer $TOKEN"
```

### Securite et transversalite

```bash
# CA-11 — Token absent
curl -s -w "\n-> HTTP %{http_code}\n" -X GET "$BASE_URL/api/v1/games/$GAME_ID/results"
# Attendu : 401 UNAUTHORIZED

# CA-12 — Role insuffisant
curl -s -w "\n-> HTTP %{http_code}\n" -X GET "$BASE_URL/api/v1/games/$GAME_ID/results" \
  -H "Authorization: Bearer $TOKEN_BUZZER"
# Attendu : 403 FORBIDDEN

# CA-14 — Methode non supportee
curl -s -w "\n-> HTTP %{http_code}\n" -X POST "$BASE_URL/api/v1/games/$GAME_ID/results" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{}'
# Attendu : 405 METHOD_NOT_ALLOWED avec header Allow: GET
```

---

## Specifications techniques

| Element | Choix |
|---|---|
| Runtime | Node.js 24 LTS (derniere version stable disponible) |
| Langage | JavaScript (ES Modules) |
| Base de donnees | SQLite |
| Tests | Jest (derniere version stable disponible) |
| Identifiants | UUIDv7 genere cote Node.js |
| Horodatage | ISO 8601 UTC (millisecondes), genere cote Node.js |
| Principes d'architecture | YAGNI, KISS, DRY, SOLID |

---

## Catalogue des erreurs

### Codes standards
Voir le [Catalogue centralise des codes d'erreur](error-codes.md#1%EF%B8%8F%E2%83%A3-codes-derreur-standards-transversaux)

### Codes specifiques a cette US

| Code erreur | Code HTTP | Message | Contexte |
|---|---|---|---|
| `GAME_NOT_COMPLETED` | `409` | `"Results are only available for completed games."` | La partie n'est pas en statut `COMPLETED` |

---

## Perimetre

| Inclus | Exclu |
|---|---|
| Endpoint REST pour recuperer les resultats finaux | Resultats en temps reel (via WebSocket, deja implemente) |
| Classement final trie par score | Pagination des resultats |
| Detail des reponses par question | Modification des resultats |
| Validation du statut COMPLETED | Resultats partiels (partie en cours) |
| Tests d'integration (couverture >= 90%) | |

---

## Points de vigilance

### Coherence avec les donnees WebSocket

Les donnees retournees par cet endpoint proviennent de la table `T_GAME_ANSWER_GAA`, la meme source de verite que les messages WebSocket `question_result` et `question_result_summary`. Il n'y a donc aucun risque de divergence.

### Performance

L'endpoint effectue une seule requete pour charger toutes les reponses d'une partie (`findAnswersByGame`), puis construit le classement en memoire. Pour le volume prevu (max 10 participants, max ~50 questions), cette approche est optimale et n'a pas besoin d'index supplementaires.

### Score final

Le score final de chaque participant est determine par la derniere valeur de `GAA_CUMULATIVE_SCORE` enregistree dans `T_GAME_ANSWER_GAA` pour ce participant. Les reponses sont triees par `GAA_QUESTION_ID` puis `GAA_PARTICIPANT_ORDER`, donc la derniere entree pour un participant represente son score cumule final.
