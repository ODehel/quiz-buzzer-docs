# US-ANG-001 — Initialisation de l'application et gestion de session

## 📋 Contexte projet

Voir [VISION.md](VISION.md) pour la description complète du projet et de ses quatre applications.

L'application Angular est l'interface de gestion des parties du maître de jeu. Elle communique avec le serveur Node.js exclusivement via l'API REST (Bearer JWT) et le WebSocket (authentification post-connexion).

---

## 🎯 User Story

> **En tant que** maître de jeu,
> **je veux** que l'application démarre et se connecte automatiquement au serveur sans écran de connexion,
> **afin de** pouvoir utiliser immédiatement l'interface sans friction d'authentification.

---

## ✅ Critères d'acceptance

> 🧪 **Exigence de couverture** — Voir [CONVENTIONS-TECHNIQUES-ANGULAR.md](CONVENTIONS-TECHNIQUES-ANGULAR.md) pour la stack, les principes KISS/DRY/YAGNI/SOLID et la couverture des tests. Chaque CA doit être couvert par au moins un test automatisé. Couverture `AuthService` ≥ 90 %, `WebSocketService` ≥ 90 %, guards 100 %.

### Auto-connexion au démarrage — `APP_INITIALIZER`

| # | Critère | Résultat attendu |
|---|---|---|
| CA-1 | Au démarrage, avant toute navigation, `AuthService.initialize()` appelle `POST /api/v1/token` avec les credentials de `environment.ts` | Appel bloquant — le Router ne résout aucune route tant que `APP_INITIALIZER` n'a pas terminé |
| CA-2 | En cas de succès (`200 OK`), le token JWT est stocké dans un signal privé de `AuthService` | `AuthService.getToken()` retourne le token ; `AuthService.isReady()` passe à `true` |
| CA-3 | En cas d'échec réseau ou de réponse non-2xx, l'application navigue vers `/error` avec un message explicite | Aucune autre navigation n'est tentée ; l'utilisateur voit une page d'erreur bloquante |
| CA-4 | `authInterceptor` injecte automatiquement le header `Authorization: Bearer <token>` sur toutes les requêtes `HttpClient` | L'injection ne se produit pas si `AuthService.getToken()` retourne `null` |
| CA-5 | `authGuard` bloque l'accès à toutes les routes protégées si `AuthService.isReady()` est `false` | Redirection vers `/error` |

### Connexion WebSocket initiale

| # | Critère | Résultat attendu |
|---|---|---|
| CA-6 | Après obtention du token, `WebSocketService` établit une connexion WebSocket vers `environment.wsUrl` | Connexion sur `ws://<serverUrl>/ws` |
| CA-7 | Le premier message envoyé est `{ "type": "auth", "token": "<JWT>" }` | Conforme au protocole US-009 |
| CA-8 | À la réception de `auth_success`, `WebSocketService` émet le message sur `messages$` | `GameStateService` reçoit le signal et peut s'initialiser |
| CA-9 | Si la connexion WebSocket échoue ou est perdue, `WebSocketService` tente de se reconnecter automatiquement avec un backoff exponentiel | Délais : 1 s, 2 s, 4 s, 8 s… jusqu'à 30 s maximum — reprise indéfinie |
| CA-10 | À chaque reconnexion, le premier message envoyé est `{ "type": "auth", "token": "<token_courant>" }` | Le token courant est lu depuis `AuthService.getToken()` au moment de la reconnexion |
| CA-11 | Si le code de fermeture WebSocket est `4002` (token expiré côté serveur), `WebSocketService` appelle `AuthService.refresh()` avant de reconnecter | Nouveau token obtenu avant d'envoyer le message d'auth |

### Refresh automatique du token

| # | Critère | Résultat attendu |
|---|---|---|
| CA-12 | À la réception de `token_expiring_soon` via WebSocket, `AuthService.refresh()` est appelé silencieusement | Appel à `POST /api/v1/token` en arrière-plan — aucune interruption visible |
| CA-13 | En cas de succès du refresh, `WebSocketService` envoie `{ "type": "auth_refresh", "token": "<nouveau_token>" }` sur la connexion WebSocket existante | La connexion WebSocket n'est pas interrompue — conforme à l'US-021 |
| CA-14 | À la réception de `auth_success` après `auth_refresh`, le timer de refresh est réinitialisé | Le nouveau `expires_in` repart de zéro |
| CA-15 | En cas d'échec du refresh (réseau indisponible), une nouvelle tentative est effectuée après 5 secondes, jusqu'à 3 fois | Après 3 échecs, la connexion WebSocket est fermée et la reconnexion complète repart depuis CA-9 |
| CA-16 | À la réception de `token_expired` (serveur a expiré la connexion), `AuthService.refresh()` est appelé puis reconnexion complète | Traitement identique à un code de fermeture `4002` |

### Synchronisation de l'état initial

| # | Critère | Résultat attendu |
|---|---|---|
| CA-17 | Après `auth_success` WebSocket, `GameStateService.syncInitial()` appelle `GET /api/v1/games` pour détecter une partie active | Filtre côté serveur : parties en statut `PENDING` ou non-`COMPLETED`/`IN_ERROR` |
| CA-18 | Si une partie active existe, son statut et ses données sont chargés dans `GameStateService` via `signal.update()` | `GameStateService.isActive()` retourne `true` ; `activeGameGuard` laisse passer |
| CA-19 | Si aucune partie active n'existe, `GameStateService` reste à son état initial | `GameStateService.isActive()` retourne `false` ; `noActiveGameGuard` laisse passer le backoffice |
| CA-20 | Si le serveur envoie `game_state_sync` immédiatement après `auth_success` WebSocket (reconnexion en cours de partie), `GameStateService` le traite via `dispatch()` | L'état est restauré depuis le message WebSocket — pas besoin d'un second appel REST |

### Navigation initiale

| # | Critère | Résultat attendu |
|---|---|---|
| CA-21 | Après initialisation réussie, le Router navigue vers `/dashboard` | `APP_INITIALIZER` terminé — navigation débloquée |
| CA-22 | Si l'URL courante au démarrage est une route protégée valide (ex. rechargement de page sur `/content/questions`), le Router y accède directement après init | Les guards évaluent l'état post-initialisation |
| CA-23 | La route `/error` est accessible sans guard — elle ne dépend pas de `AuthService.isReady()` | Accessible même si l'auto-login a échoué |

---

## 🔧 Spécifications techniques

Voir [CONVENTIONS-TECHNIQUES-ANGULAR.md](CONVENTIONS-TECHNIQUES-ANGULAR.md) pour la stack complète, les principes KISS/DRY/YAGNI/SOLID et les conventions de code.

### `environment.ts`

```typescript
export const environment = {
  production:     false,
  serverUrl:      'http://192.168.1.10:3000',
  wsUrl:          'ws://192.168.1.10:3000/ws',
  adminUsername:  'admin',
  adminPassword:  'MonSuperMotDePasse!'
  // ⚠️ Ne pas versionner le fichier .env — utiliser environment.prod.ts
  //    avec des valeurs lues depuis la CI/CD en production
};
```

### `AuthService` — interface publique

```typescript
@Injectable({ providedIn: 'root' })
export class AuthService {
  readonly isReady = signal(false);   // true après init réussie

  async initialize(): Promise<void>;  // appelé par APP_INITIALIZER
  async refresh(): Promise<void>;     // appelé sur token_expiring_soon / 4002
  getToken(): string | null;          // lu par authInterceptor et WebSocketService
}
```

### `WebSocketService` — interface publique

```typescript
@Injectable({ providedIn: 'root' })
export class WebSocketService {
  readonly messages$: Observable<InboundMessage>; // partagé (shareReplay)

  connect(): void;                    // appelé par APP_INITIALIZER
  send(msg: OutboundMessage): void;   // appelé par composants et services
}
```

### Flux d'initialisation complet

```
APP_INITIALIZER (bloquant)
  1. AuthService.initialize()
       → POST /api/v1/token
         → Succès : token stocké, isReady = true
         → Échec  : navigate('/error') — fin de l'initialisation

  2. WebSocketService.connect()
       → new WebSocket(environment.wsUrl)
       → send { type: 'auth', token }
       → réception auth_success → messages$ émet

  3. GameStateService.syncInitial()
       → GET /api/v1/games
       → si partie active → signal mis à jour
       → si game_state_sync reçu en parallèle → dispatch() prend le dessus

  4. Router débloqué → navigate('/dashboard')
```

### Backoff exponentiel WebSocket

```typescript
// Dans WebSocketService.buildStream()
retryWhen(errors =>
  errors.pipe(
    scan((attempt, err) => {
      if (err?.code === 4002) { /* refresh token avant retry */ }
      return attempt + 1;
    }, 0),
    delayWhen(attempt => timer(Math.min(1000 * Math.pow(2, attempt), 30_000)))
  )
)
```

### `authInterceptor`

```typescript
export const authInterceptor: HttpInterceptorFn = (req, next) => {
  const token = inject(AuthService).getToken();
  if (!token) return next(req);
  return next(req.clone({
    setHeaders: { Authorization: `Bearer ${token}` }
  }));
};
```

---

## 📐 Périmètre

| Inclus | Exclu |
|---|---|
| Auto-login silencieux via `POST /api/v1/token` | Écran de connexion utilisateur |
| Stockage du token JWT en mémoire (signal) | Stockage du token en `localStorage` / `sessionStorage` |
| Connexion WebSocket avec authentification post-connexion | Gestion des messages métier WebSocket (→ `GameStateService`) |
| Reconnexion automatique avec backoff exponentiel | Reconnexion infinie sans backoff |
| Refresh silencieux sur `token_expiring_soon` via `auth_refresh` | Refresh token REST (YAGNI) |
| Synchronisation initiale de l'état de la partie | Affichage du dashboard (→ US-ANG-002) |
| `authGuard`, `activeGameGuard`, `noActiveGameGuard` | Logique de routing métier (→ US dédiées) |
| Page d'erreur bloquante en cas d'échec d'initialisation | Retry automatique de l'initialisation |
| Tests unitaires et d'intégration (couverture ≥ 90 %) | Déploiement / CI-CD |

---

## 🔍 Points de vigilance

### `APP_INITIALIZER` doit être strictement bloquant

Angular résout les routes immédiatement après la fin de `APP_INITIALIZER`. Si `initialize()` ne retourne pas une `Promise` résolue, les guards s'exécuteront avec un état non initialisé. `AuthService.isReady()` doit impérativement être `true` avant que le Router ne commence à évaluer les guards.

### Pas de token en `localStorage`

Le token est stocké **uniquement en mémoire** via un `signal` privé dans `AuthService`. Un rechargement de page (F5) relance l'`APP_INITIALIZER` et obtient un nouveau token — c'est le comportement attendu. Stocker en `localStorage` introduirait un risque XSS et une complexité non justifiée (YAGNI).

### `messages$` doit être `shareReplay`

Plusieurs services (`GameStateService`, éventuellement d'autres) s'abonnent à `messages$`. Sans `shareReplay({ bufferSize: 1, refCount: true })`, chaque abonné créerait une nouvelle connexion WebSocket. Le `shareReplay` garantit qu'un seul socket est ouvert et que les nouveaux abonnés reçoivent le dernier message émis.

### Race condition `game_state_sync` vs `GET /api/v1/games`

`WebSocketService.connect()` et `GameStateService.syncInitial()` s'exécutent en parallèle dans l'`APP_INITIALIZER`. Il est possible que `game_state_sync` arrive via WebSocket avant que `GET /api/v1/games` ne réponde. `dispatch()` dans `GameStateService` prend toujours le dessus : il met à jour le signal avec les données les plus fraîches du serveur, quelle que soit leur source. L'ordre d'arrivée est sans importance grâce aux Signals.

### Cas `4004` (session replaced)

Si l'application est ouverte dans deux onglets, le serveur ferme la première connexion avec `4004`. `WebSocketService` doit traiter ce code comme une erreur non-retry (le second onglet a pris la main) et naviguer vers `/error` plutôt que de tenter une reconnexion infinie.

---

## 🔗 Documents liés

| Document | Contenu |
|---|---|
| [VISION.md](VISION.md) | Description complète du projet |
| [CONVENTIONS-TECHNIQUES-ANGULAR.md](CONVENTIONS-TECHNIQUES-ANGULAR.md) | Stack, principes, conventions de code Angular |
| [US-003 — Authentification JWT (serveur)](US-003-authentication-token.md) | Endpoint `POST /api/v1/token` |
| [US-009 — Connexion WebSocket (serveur)](US-009-websocket-connection.md) | Protocole d'auth WebSocket |
| [US-019 — Reprise après crash (serveur)](US-019-game-recovery.md) | Format `game_state_sync` |
| [US-021 — Refresh JWT WebSocket (serveur)](US-021-token-refresh.md) | Protocole `token_expiring_soon` / `auth_refresh` |

---

**Dernière mise à jour** : 2026-03-28
**Statut** : Rédigée — en attente d'implémentation (Sprint 0)
**Sprint** : 0
