# 🔐 Annexe — Critères de sécurité transversaux

## Contexte

Cette annexe centralise les **critères d'acceptation (CA) de sécurité transversaux** qui s'appliquent à **toutes les routes protégées** du projet **Quiz Buzzer**. Plutôt que de répéter ces critères dans chaque US avec des numéros de CA différents, ce document sert de référence unique.

> **Principe DRY** — Cette annexe élimine la duplication. Chaque US avec des routes protégées doit la référencer.

---

## ✅ Critères de sécurité transversaux

### Protection par Bearer token (401 UNAUTHORIZED)

| Critère | Résultat attendu |
|---|---|
| **Toutes les routes protégées** doivent exiger un Bearer token dans le header `Authorization` | Token absent/invalide/expiré → `401 UNAUTHORIZED` |
| **Token absent** (header `Authorization` manquant) | `401 UNAUTHORIZED` avec message générique |
| **Token invalide** (signature invalide, format incorrect) | `401 UNAUTHORIZED` avec message générique |
| **Token expiré** (timestamp `exp` dépassé) | `401 UNAUTHORIZED` avec message générique |
| Format du header requis | `Authorization: Bearer <token_jwt>` |

**Format de la réponse `401 UNAUTHORIZED` :**

```json
{
  "error": "UNAUTHORIZED",
  "message": "Missing or invalid authorization token."
}
```

---

### Contrôle d'accès par rôle (403 FORBIDDEN)

| Critère | Résultat attendu |
|---|---|
| **Routes réservées aux administrateurs** | Rôle `buzzer` → `403 FORBIDDEN` |
| Seuls les utilisateurs avec le rôle `admin` peuvent accéder aux routes protégées en écriture (POST, PUT, PATCH, DELETE) | Rôle insuffisant → `403 FORBIDDEN` avec message générique |

**Format de la réponse `403 FORBIDDEN` :**

```json
{
  "error": "FORBIDDEN",
  "message": "Insufficient permissions for this operation."
}
```

---

### Rate limiting (429 RATE_LIMIT_EXCEEDED)

| Critère | Résultat attendu |
|---|---|
| **Limite globale** : max **100 requêtes par minute par adresse IP** | Dépassement → `429 RATE_LIMIT_EXCEEDED` |
| **Header de réessai** : `Retry-After: 60` (secondes avant la prochaine tentative) | Obligatoire dans la réponse 429 |
| La limite s'applique à **toutes les routes** (authentifiées ou non) | Même `/api/v1/token` est limité |
| Le comptage se fait **par adresse IP source** | Les proxys/load-balancers doivent transmettre `X-Forwarded-For` |

**Format de la réponse `429 RATE_LIMIT_EXCEEDED` :**

```json
{
  "error": "RATE_LIMIT_EXCEEDED",
  "message": "Too many requests. Please retry after 60 seconds."
}
```

**Headers de la réponse :**

```
HTTP/1.1 429 Too Many Requests
Retry-After: 60
Content-Type: application/json
```

---

### Méthodes HTTP non supportées (405 METHOD_NOT_ALLOWED)

| Critère | Résultat attendu |
|---|---|
| **Méthode HTTP non supportée** sur une ressource | `405 METHOD_NOT_ALLOWED` |
| **Header `Allow`** doit lister les méthodes supportées pour cette ressource | Exemple : `Allow: GET, POST` |
| Les routes supportent une combinaison de : `GET`, `POST`, `PUT`, `PATCH`, `DELETE` | Autres méthodes (`HEAD`, `OPTIONS`, etc.) → `405` |

**Format de la réponse `405 METHOD_NOT_ALLOWED` :**

```json
{
  "error": "METHOD_NOT_ALLOWED",
  "message": "Method not allowed on this resource."
}
```

**Headers de la réponse :**

```
HTTP/1.1 405 Method Not Allowed
Allow: GET, POST
Content-Type: application/json
```

---

### Erreurs serveur (500 INTERNAL_SERVER_ERROR)

| Critère | Résultat attendu |
|---|---|
| **Erreur inattendue** (exception non capturée, crash serveur, etc.) | `500 INTERNAL_SERVER_ERROR` |
| **Aucun détail technique** ne doit être exposé dans la réponse API | Pas de stack trace, pas de message SQL, pas de chemins internes |
| Les détails techniques doivent être consignés **uniquement dans les logs serveur** | Format JSON structuré avec correlation ID |
| La réponse doit être générique et reproductible | Facilite le déploiement sans révéler l'infrastructure |

**Format de la réponse `500 INTERNAL_SERVER_ERROR` :**

```json
{
  "error": "INTERNAL_SERVER_ERROR",
  "message": "An unexpected error occurred. Please try again later."
}
```

**Logging structuré côté serveur (exemple) :**

```json
{
  "timestamp": "2026-03-25T14:30:00.000Z",
  "level": "ERROR",
  "event": "UNHANDLED_EXCEPTION",
  "error": "TypeError: Cannot read property 'name' of null",
  "stack": "at Object.getTheme (/app/src/routes/themes.js:42:15)",
  "path": "/api/v1/themes/invalid-uuid",
  "method": "GET",
  "ip": "192.168.1.100",
  "correlationId": "req-2026-03-25-abc123def"
}
```

---

### Content-Type obligatoire (415 UNSUPPORTED_MEDIA_TYPE)

| Critère | Résultat attendu |
|---|---|
| **Routes avec body** (POST, PUT, PATCH) exigent `Content-Type: application/json` | Autre type → `415 UNSUPPORTED_MEDIA_TYPE` |
| Les routes **sans body** (GET, DELETE) ignorent le `Content-Type` | Quelle que soit sa valeur, aucune validation n'est effectuée |
| Le serveur ne doit pas interpréter d'autres formats (XML, form-encoded, etc.) sur les routes qui attendent JSON | Rejeter avec `415` |

**Format de la réponse `415 UNSUPPORTED_MEDIA_TYPE` :**

```json
{
  "error": "UNSUPPORTED_MEDIA_TYPE",
  "message": "Content-Type must be 'application/json'."
}
```

---

## 🧪 Cas de tests transversaux

### Prérequis pour tous les tests

```bash
BASE_URL=http://localhost:3000
TOKEN=<votre_token_JWT_admin>          # Obtenu via POST /api/v1/token (US-003)
TOKEN_BUZZER=<token_JWT_buzzer>        # Token avec rôle buzzer
TOKEN_INVALID="invalid.token.here"
```

---

### CA-Bearer — Token absent → `401 UNAUTHORIZED`

```bash
curl -s -w "\n→ HTTP %{http_code}\n" -X GET "$BASE_URL/api/v1/themes"
# Attendu : 401 UNAUTHORIZED
```

---

### CA-Bearer — Token invalide → `401 UNAUTHORIZED`

```bash
curl -s -w "\n→ HTTP %{http_code}\n" -X GET "$BASE_URL/api/v1/themes" \
  -H "Authorization: Bearer $TOKEN_INVALID"
# Attendu : 401 UNAUTHORIZED
```

---

### CA-Bearer — Token expiré → `401 UNAUTHORIZED`

```bash
# Créer un token expiré (ajuster JWT_EXPIRATION à -3600 avant de générer)
EXPIRED_TOKEN=$(node -e "const jwt = require('jsonwebtoken'); \
  const payload = { sub: '018e4f5a', role: 'admin', iat: Math.floor(Date.now()/1000)-7200, exp: Math.floor(Date.now()/1000)-3600 }; \
  console.log(jwt.sign(payload, process.env.JWT_SECRET, { algorithm: 'HS256' }));")

curl -s -w "\n→ HTTP %{http_code}\n" -X GET "$BASE_URL/api/v1/themes" \
  -H "Authorization: Bearer $EXPIRED_TOKEN"
# Attendu : 401 UNAUTHORIZED
```

---

### CA-Forbidden — Rôle insuffisant → `403 FORBIDDEN`

```bash
# Utiliser TOKEN_BUZZER (rôle 'buzzer') sur une route réservée aux admins
curl -s -w "\n→ HTTP %{http_code}\n" -X POST "$BASE_URL/api/v1/themes" \
  -H "Authorization: Bearer $TOKEN_BUZZER" \
  -H "Content-Type: application/json" \
  -d '{"name": "Science fiction"}'
# Attendu : 403 FORBIDDEN
```

---

### CA-RateLimit — Dépassement → `429 RATE_LIMIT_EXCEEDED`

```bash
# Effectuer 101 requêtes rapidement
for i in $(seq 1 101); do
  HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -X GET "$BASE_URL/api/v1/themes" \
    -H "Authorization: Bearer $TOKEN")

  if [ "$HTTP_CODE" = "429" ]; then
    echo "Request $i: $HTTP_CODE (rate limited)"
    # Vérifier que le header Retry-After est présent
    curl -s -i -X GET "$BASE_URL/api/v1/themes" \
      -H "Authorization: Bearer $TOKEN" | grep -i "Retry-After"
    break
  fi
done
# Attendu : 101ème requête → 429 avec header Retry-After: 60
```

---

### CA-MethodNotAllowed — Méthode non supportée → `405 METHOD_NOT_ALLOWED`

```bash
# Exemple : PATCH sur une route qui ne supporte que GET/POST
curl -s -v -w "\n→ HTTP %{http_code}\n" -X PATCH "$BASE_URL/api/v1/themes" \
  -H "Authorization: Bearer $TOKEN"
# Attendu : 405 METHOD_NOT_ALLOWED avec header "Allow: GET, POST"
```

---

### CA-InternalError — Erreur serveur → `500 INTERNAL_SERVER_ERROR`

```bash
# Cette action doit provoquer une erreur non gérée (test injecté manuellement)
# Exemple : envoyer un UUID valide mais causant une erreur en base

# Vérifier que la réponse ne contient pas de stack trace :
curl -s -X GET "$BASE_URL/api/v1/themes/00000000-0000-0000-0000-000000000000" \
  -H "Authorization: Bearer $TOKEN" | jq .
# Attendu : 500 sans détails techniques
# Logs serveur : doivent contenir la stack trace complète
```

---

### CA-ContentType — Content-Type incorrect → `415 UNSUPPORTED_MEDIA_TYPE`

```bash
# POST avec Content-Type: text/plain
curl -s -w "\n→ HTTP %{http_code}\n" -X POST "$BASE_URL/api/v1/themes" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: text/plain" \
  -d '{"name": "Musique"}'
# Attendu : 415 UNSUPPORTED_MEDIA_TYPE

# DELETE avec n'importe quel Content-Type (ignoré sur GET/DELETE)
curl -s -w "\n→ HTTP %{http_code}\n" -X DELETE "$BASE_URL/api/v1/themes/some-id" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: text/xml"
# Attendu : 204 (ignoré sur GET/DELETE, pas de validation du Content-Type)
```

---

## 📋 Intégration dans les US

Chaque US contenant des routes protégées doit :

1. **Référencer cette annexe** dans sa section "Sécurité et transversalité" :
   ```markdown
   ### Sécurité et transversalité

   Voir [Annexe — Critères de sécurité transversaux](SECURITE-TRANSVERSALE.md)

   Cette US ajoute les critères spécifiques suivants :
   ```

2. **Spécifier les numéros de CA locaux** qui correspondent à ces critères :
   ```markdown
   | # | Critère | Résultat attendu |
   |---|---|---|
   | CA-XX | Voir CA-Bearer dans l'annexe transversale | `401 UNAUTHORIZED` |
   | CA-XX | Voir CA-Forbidden dans l'annexe transversale | `403 FORBIDDEN` |
   | CA-XX | Voir CA-RateLimit dans l'annexe transversale | `429 RATE_LIMIT_EXCEEDED` |
   | CA-XX | Voir CA-MethodNotAllowed dans l'annexe transversale | `405 METHOD_NOT_ALLOWED` |
   | CA-XX | Voir CA-InternalError dans l'annexe transversale | `500 INTERNAL_SERVER_ERROR` |
   ```

3. **Conserver les cas de test spécifiques** à l'US (CA-1, CA-2, etc.) dans la section "Cas de tests — requêtes cURL".

4. **Réutiliser les cas de tests transversaux** en y ajoutant le contexte de l'US (remplacer les ressources et les variables).

---

## 🔒 Principes généraux de sécurité

### Timing attacks

- Les erreurs d'authentification (401) doivent avoir des temps de réponse identiques, que le token soit invalide ou absent.
- Les validations d'existence (ex. : ID inexistant) doivent effectuer des opérations factices pour éviter les timing attacks.

### Logging de sécurité

- **Succès** : logger l'authentification, l'autorisation, l'accès aux ressources (niveau `INFO`).
- **Échechs** : logger les tentatives échouées, les accès refusés, les rate limits (niveau `WARN`).
- **Erreurs** : logger les exceptions non gérées avec la stack trace (niveau `ERROR`).
- Format JSON structuré avec horodatage, IP source, et correlation ID pour le debugging.

### Traçabilité (Correlation ID)

- Chaque requête reçoit un **correlation ID unique** (UUIDv7).
- Ce correlation ID est inclus dans les logs, les réponses d'erreur 5xx, et les headers de réponse.
- Facilite le debugging côté client et serveur.

---

## 📚 Références

- [RFC 7235 — Authentication & Authorization in HTTP](https://tools.ietf.org/html/rfc7235)
- [RFC 7231 — HTTP Semantics & Content](https://tools.ietf.org/html/rfc7231#section-6.5.5) (codes HTTP)
- [OWASP Top 10 — 2021](https://owasp.org/Top10/)
- [JWT Best Practices — RFC 8725](https://tools.ietf.org/html/rfc8725)
- [Rate Limiting Headers — Draft RateLimit Header Fields for HTTP](https://datatracker.ietf.org/doc/draft-ietf-httpapi-ratelimit-headers/)

---

**Dernière mise à jour** : 2026-03-25
**Statut** : Transversal à toutes les US avec routes protégées
