# 🔐 Annexe — Authentification et autorisation

> **Référence unique** — Ce document centralise le mécanisme d'authentification et d'autorisation JWT commun à toutes les routes protégées du projet **Quiz Buzzer**. Chaque US avec des routes protégées **référence** ce document au lieu de dupliquer ces informations.

---

## 📋 Mécanisme JWT

Toutes les routes protégées exigent un **JSON Web Token (JWT)** transmis via le header HTTP `Authorization`.

| Élément | Valeur |
|---|---|
| Type de token | JWT |
| Algorithme de signature | HS256 (symétrique) |
| Transmission | Header `Authorization: Bearer <token>` |
| Secret de signature | Variable d'environnement `JWT_SECRET` (min 32 caractères) |
| Durée de validité | 1 heure (3600s), configurable via variable d'environnement `JWT_EXPIRATION` |
| Émission | `POST /api/v1/token` ([US-003](../hub/US-003-authentication-token.md)) |
| Renouvellement WebSocket | Message `auth_refresh` ([US-021](../hub/US-021-token-refresh.md)) |

---

## 🪪 Structure du payload JWT

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
| `role` | `string` | Rôle de l'utilisateur (`"admin"` ou `"buzzer"`) |
| `iat` (issued at) | `number` | Timestamp Unix de l'émission (automatique) |
| `exp` (expiration) | `number` | Timestamp Unix d'expiration (automatique) |

---

## 🏗️ Architecture middleware — Chaîne de vérification

Deux middlewares distincts sont chaînés sur chaque route protégée, conformément au **principe de responsabilité unique (SRP / SOLID)** :

### Middleware 1 — `authenticate` (vérification du token)

```
Requête entrante
  → Header "Authorization" présent ?
    → Non → 401 UNAUTHORIZED
  → Format "Bearer <token>" valide ?
    → Non → 401 UNAUTHORIZED
  → Décodage et vérification du JWT (signature + expiration)
    → Échec → 401 UNAUTHORIZED
  → ✅ Injecte les claims décodés dans l'objet requête (req.user)
```

### Middleware 2 — `authorize(role)` (vérification du rôle)

```
req.user disponible ?
  → Non → 401 UNAUTHORIZED (sécurité défensive)
  → req.user.role === rôle attendu ?
    → Non → 403 FORBIDDEN
    → ✅ Passe au handler suivant
```

### Application sur les routes

```javascript
router.post('/api/v1/[ressource]',       authenticate, authorize('admin'), handler);
router.get('/api/v1/[ressource]',        authenticate, authorize('admin'), handler);
router.get('/api/v1/[ressource]/:id',    authenticate, authorize('admin'), handler);
router.put('/api/v1/[ressource]/:id',    authenticate, authorize('admin'), handler);
router.delete('/api/v1/[ressource]/:id', authenticate, authorize('admin'), handler);
```

> **Réutilisabilité (DRY / SOLID)** — Les middlewares `authenticate` et `authorize` sont définis **une seule fois** dans l'[US-003](../hub/US-003-authentication-token.md) et réutilisés par toutes les US avec des routes protégées. Le middleware `authorize` accepte n'importe quel rôle en paramètre, permettant de supporter d'autres profils sans modification du middleware lui-même (**Open/Closed Principle — SOLID**).

---

## 🌐 Contextes d'utilisation du token

Le token JWT émis par `POST /api/v1/token` (../hub/US-003) est utilisé dans deux contextes :

| Contexte | Mécanisme | US associée |
|---|---|---|
| **API REST** | Header `Authorization: Bearer <token>` à chaque requête | US-004 et suivantes |
| **WebSocket** | Authentification post-connexion (premier message `{ "type": "auth", "token": "<JWT>" }`) | [US-009](../hub/US-009-websocket-connection.md) |

> **Note :** L'expiration du token dans la réponse `auth_success` WebSocket est **calculée dynamiquement** comme `Math.floor(token.exp - Date.now() / 1000)`, pour refléter le temps réel restant et non l'expiration initiale.

---

## 📋 Intégration dans les US

Chaque US avec des routes protégées doit référencer ce document :

```markdown
## 🔐 Authentification et autorisation

Voir l'[Annexe — Authentification et autorisation](AUTHENTIFICATION.md) pour le mécanisme JWT, la structure du payload et l'architecture middleware.

Les middlewares `authenticate` et `authorize('admin')` définis en [US-003](../hub/US-003-authentication-token.md) sont réutilisés sur toutes les routes de cette US.
```

---

## 🔗 Documents liés

| Document | Contenu |
|---|---|
| [US-003 — Authentification et émission du token JWT](../hub/US-003-authentication-token.md) | Endpoint `POST /api/v1/token`, émission du token, table `T_USER_USR` |
| [US-009 — Connexion WebSocket](../hub/US-009-websocket-connection.md) | Authentification WebSocket post-connexion |
| [US-021 — Refresh du token JWT](../hub/US-021-token-refresh.md) | Renouvellement du token via WebSocket |
| [Annexe — Critères de sécurité transversaux](SECURITE-TRANSVERSALE.md) | Cas de test Bearer, Forbidden, Rate limiting |
| [Catalogue centralisé des codes d'erreur](../hub/error-codes.md) | Codes `UNAUTHORIZED`, `FORBIDDEN` |

---

**Dernière mise à jour** : 2026-03-28
**Statut** : Transversal à toutes les US avec routes protégées
