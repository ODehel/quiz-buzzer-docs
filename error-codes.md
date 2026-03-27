# 📚 Catalogue centralisé des codes d'erreur

> **Référence unique** — Ce document est la source unique de vérité pour tous les codes d'erreur de l'API Quiz Buzzer. Chaque User Story (US) **référence** ce catalogue au lieu de dupliquer les codes.

---

## 🎯 Organisation du catalogue

### 1️⃣ Codes d'erreur standards (transversaux)

Codes communs à **toutes les US**, appliquées globalement par le serveur :

| Code erreur | Code HTTP | Message | Contexte |
|---|---|---|---|
| `VALIDATION_ERROR` | `400` | _(dynamique selon le cas)_ | Champ manquant, vide, format invalide, validation métier échouée |
| `INVALID_JSON` | `400` | `"Request body must be valid JSON."` | Corps non parseable |
| `INVALID_BODY` | `400` | `"Request body must be a JSON object."` | Le corps de la requête est du JSON valide mais n'est pas un objet (ex : tableau, null, primitive) |
| `INVALID_UUID` | `400` | `"The provided ID is not a valid UUID."` | ID mal formé dans l'URL ou le body |
| `UNKNOWN_FIELDS` | `400` | `"Unknown field(s): foo, bar."` | Champs non reconnus dans le body |
| `ID_MISMATCH` | `400` | `"The ID in the request body does not match the URL parameter."` | ID body ≠ ID URL |
| `INVALID_PAGINATION` | `400` | `"Invalid pagination parameters."` | Paramètres `page`/`limit` invalides (négatifs, zéro, non numériques, limit > max) |
| `IMMUTABLE_FIELD` | `400` | `"<field> cannot be changed after creation."` | Tentative de modification d'un champ immuable |
| `UNAUTHORIZED` | `401` | `"Authentication token is missing or invalid."` | Token absent/expiré/invalide |
| `FORBIDDEN` | `403` | `"You do not have permission to perform this action."` | Rôle insuffisant ou permission manquante |
| `NOT_FOUND` | `404` | `"The requested <resource> was not found."` | Ressource inexistante (dynamique selon le contexte) |
| `METHOD_NOT_ALLOWED` | `405` | `"HTTP method <METHOD> is not allowed on this resource."` | Méthode HTTP non supportée (message dynamique) |
| `UNSUPPORTED_MEDIA_TYPE` | `415` | `"Content-Type must be 'application/json'."` | Content-Type incorrect |
| `RATE_LIMIT_EXCEEDED` | `429` | `"Too many requests. Please retry in 60 seconds."` | Dépassement du rate limit (header `Retry-After: 60`) |
| `INTERNAL_SERVER_ERROR` | `500` | `"An unexpected error occurred. Please try again later."` | Erreur serveur (aucun détail technique exposé) |

---

### 2️⃣ Codes d'erreur spécifiques par domaine

#### **Authentification & Token (US-003)**

| Code erreur | Code HTTP | Message | Contexte |
|---|---|---|---|
| `INVALID_CREDENTIALS` | `401` | `"Invalid credentials."` | Username ou password incorrect (message générique ne révélant pas lequel est faux) |

---

#### **Thèmes (US-004)**

| Code erreur | Code HTTP | Message | Contexte |
|---|---|---|---|
| `THEME_ALREADY_EXISTS` | `409` | `"A theme with this name already exists."` | Doublon de nom de thème (comparaison insensible à la casse) |
| `THEME_HAS_QUESTIONS` | `409` | `"Cannot delete this theme: questions are still associated with it."` | Suppression d'un thème avec questions liées |

---

#### **Questions (US-005 & US-006)**

| Code erreur | Code HTTP | Message | Contexte |
|---|---|---|---|
| `INVALID_THEME` | `400` | `"The provided theme_id does not reference an existing theme."` | Référence de thème inexistant |
| `TYPE_CHANGE_NOT_ALLOWED` | `400` | `"The question type cannot be changed."` | Tentative de changement de type (MCQ ↔ SPEED) via PUT |
| `INVALID_FILTER` | `400` | `"Invalid filter parameters."` | Filtres invalides (type inconnu, UUID mal formé, thème inexistant, plage incohérente, conflit exact/plage) — US-006 |
| `QUESTION_ALREADY_EXISTS` | `409` | `"A question with this title already exists."` | Doublon de titre (comparaison insensible à la casse) |

---

#### **Quiz (US-008)**

| Code erreur | Code HTTP | Message | Contexte |
|---|---|---|---|
| `QUIZ_ALREADY_EXISTS` | `409` | `"A quiz with this name already exists."` | Doublon de nom de quiz (comparaison insensible à la casse) |
| `QUESTION_NOT_FOUND` | `404` | `"Question not found: <id>."` | Question référencée dans le quiz inexistante |
| `QUESTION_IN_QUIZ` | `409` | `"Cannot delete this question: it belongs to one or more quizzes."` | Suppression d'une question utilisée dans un quiz |
| `QUIZ_IN_USE` | `403` | `"Cannot delete this quiz: it is referenced by an active game."` | Suppression d'un quiz référencé par une partie active (tous les états sauf `COMPLETED` ou `IN_ERROR`) |

---

#### **Parties (US-010)**

| Code erreur | Code HTTP | Message | Contexte |
|---|---|---|---|
| `QUIZ_NOT_FOUND` | `404` | `"The requested quiz was not found."` | Quiz référencé inexistant |
| `ACTIVE_GAME_EXISTS` | `409` | `"A game is already active. Delete it before creating a new one."` | Création impossible : une partie active (tous les états sauf `COMPLETED` ou `IN_ERROR`) existe déjà |
| `PARTICIPANT_NOT_FOUND` | `404` | `"No participant found at order <n> for this game."` | Position de participant inexistante (PATCH) |
| `INVALID_TRANSITION` | `422` | `"Cannot transition from <current> to <target>."` | Transition de statut interdite par la machine à états |

---

#### **Resultats de partie (US-013)**

| Code erreur | Code HTTP | Message | Contexte |
|---|---|---|---|
| `GAME_NOT_COMPLETED` | `409` | `"Results are only available for completed games."` | Tentative de consulter les resultats d'une partie non terminee |

---

#### **Workflows & WebSocket (US-009, US-011, US-012)**

> Codes spécifiques aux workflows MCQ/SPEED et WebSocket.
> _(À ajouter lors de l'implémentation de ces US)_

---

## 📋 Format standard des réponses d'erreur

Toutes les réponses d'erreur de l'API suivent ce format JSON standardisé :

```json
{
  "status": <HTTP_CODE>,
  "error": "CODE_ERREUR",
  "message": "Human-readable message"
}
```

### Exemples

**Erreur 400 — Validation échouée :**
```json
{
  "status": 400,
  "error": "VALIDATION_ERROR",
  "message": "Theme name must start with an uppercase letter."
}
```

**Erreur 401 — Token absent ou expiré :**
```json
{
  "status": 401,
  "error": "UNAUTHORIZED",
  "message": "Authentication token is missing or invalid."
}
```

**Erreur 404 — Ressource inexistante :**
```json
{
  "status": 404,
  "error": "NOT_FOUND",
  "message": "The requested theme was not found."
}
```

**Erreur 409 — Conflit (doublon) :**
```json
{
  "status": 409,
  "error": "THEME_ALREADY_EXISTS",
  "message": "A theme with this name already exists."
}
```

---

## 🔄 Règles de sélection du code d'erreur

Pour **créer un nouveau code d'erreur** ou **choisir lequel utiliser** :

1. **Vérifier si un code standard existe** : avant de créer un code spécifique, préférer les codes standards (cf. section 1)
2. **Si standard insuffisant** : créer un code spécifique au domaine (cf. section 2)
3. **Message dynamique vs static** : certains codes ont des messages fixes (ex: `INVALID_CREDENTIALS`), d'autres dynamiques (ex: `VALIDATION_ERROR`, `METHOD_NOT_ALLOWED`)
4. **Code HTTP** : respecter strictement les codes HTTP recommandés selon le type d'erreur :
   - `400` : erreur côté client (validation, format)
   - `401` : authentification manquante ou invalide
   - `403` : authentification OK, mais permission insuffisante
   - `404` : ressource inexistante
   - `405` : méthode HTTP non supportée
   - `409` : conflit (doublon, dépendance, état incompatible)
   - `415` : type de contenu non supporté
   - `422` : entité non traitable (ex: transition interdite)
   - `429` : trop de requêtes (rate limit)
   - `500` : erreur serveur

---

## 🔗 Principes DRY & Maintenance

### Avantages de ce catalogue centralisé

✅ **Source unique de vérité** : chaque code est défini une seule fois
✅ **Cohérence garantie** : tous les messages et codes HTTP sont synchronisés
✅ **Maintenance simplifiée** : corriger un message ne nécessite qu'une seule édition
✅ **Réduction du risque de divergence** : impossible d'avoir `CONFLICT` vs `QUIZ_ALREADY_EXISTS`
✅ **Évolutivité** : ajouter un nouveau code est facile et centralisé

### Comment référencer ce catalogue

Chaque US doit :

```markdown
## 🚨 Catalogue des erreurs

### Codes standards
Voir le [Catalogue centralisé des codes d'erreur](error-codes.md#1️⃣-codes-derreur-standards-transversaux)

### Codes spécifiques à cette US
Voir le [Catalogue centralisé — Domaine](error-codes.md#2️⃣-codes-derreur-spécifiques-par-domaine)

| Code erreur | Code HTTP | Message | Contexte |
|---|---|---|---|
| `THEME_ALREADY_EXISTS` | `409` | `"A theme with this name already exists."` | Doublon de nom |
| ... |
```

---

## 📊 Tableau récapitulatif complet

Pour une vue d'ensemble rapide, voici tous les codes documentés :

| Code | HTTP | US | Catégorie |
|---|---|---|---|
| `VALIDATION_ERROR` | 400 | Toutes | Standard |
| `INVALID_JSON` | 400 | Toutes | Standard |
| `INVALID_BODY` | 400 | Toutes | Standard |
| `INVALID_UUID` | 400 | Toutes | Standard |
| `UNKNOWN_FIELDS` | 400 | Toutes | Standard |
| `ID_MISMATCH` | 400 | Toutes | Standard |
| `INVALID_PAGINATION` | 400 | Toutes | Standard |
| `IMMUTABLE_FIELD` | 400 | Toutes | Standard |
| `INVALID_THEME` | 400 | US-005/006 | Questions |
| `INVALID_FILTER` | 400 | US-005/006 | Questions |
| `INVALID_CREDENTIALS` | 401 | US-003 | Auth |
| `UNAUTHORIZED` | 401 | Toutes | Standard |
| `FORBIDDEN` | 403 | Toutes | Standard |
| `QUIZ_IN_USE` | 403 | US-008/010 | Quiz |
| `NOT_FOUND` | 404 | Toutes | Standard |
| `QUESTION_NOT_FOUND` | 404 | US-008 | Quiz |
| `QUIZ_NOT_FOUND` | 404 | US-010 | Game |
| `PARTICIPANT_NOT_FOUND` | 404 | US-010 | Game |
| `METHOD_NOT_ALLOWED` | 405 | Toutes | Standard |
| `UNSUPPORTED_MEDIA_TYPE` | 415 | Toutes | Standard |
| `RATE_LIMIT_EXCEEDED` | 429 | Toutes | Standard |
| `THEME_ALREADY_EXISTS` | 409 | US-004 | Theme |
| `THEME_HAS_QUESTIONS` | 409 | US-004 | Theme |
| `QUESTION_ALREADY_EXISTS` | 409 | US-005/006 | Questions |
| `QUIZ_ALREADY_EXISTS` | 409 | US-008 | Quiz |
| `QUESTION_IN_QUIZ` | 409 | US-008 | Quiz |
| `ACTIVE_GAME_EXISTS` | 409 | US-010 | Game |
| `INVALID_TRANSITION` | 422 | US-010 | Game |
| `GAME_NOT_COMPLETED` | 409 | US-013 | Game Results |
| `INTERNAL_SERVER_ERROR` | 500 | Toutes | Standard |

---

## 🛠️ Notes pour les implémenteurs

### Générer des messages dynamiques

Pour les codes avec messages dynamiques (ex: `VALIDATION_ERROR`), le message doit être spécifique au contexte :

```javascript
// ✅ Bon
throw new ValidationError("Theme name must start with an uppercase letter.");

// ❌ Mauvais
throw new ValidationError("Validation failed");
```

### Lister les erreurs propres à une US

Lorsqu'une US implémente des endpoints, elle doit répertorier **tous les codes d'erreur possibles** dans sa section "Catalogue des erreurs", séparant les codes standards des codes spécifiques.

### Support multilingue (futur)

Ce catalogue utilise l'anglais pour tous les messages. En cas de besoin de localisation future, un système de clés i18n peut être ajouté sans changer la structure de ce document.

---

**Dernière mise à jour** : 2026-03-25
**Mainteneur** : Architecture API Quiz Buzzer
**Statut** : Production
