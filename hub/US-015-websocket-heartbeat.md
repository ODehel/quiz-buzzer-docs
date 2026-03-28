# US-015 — Heartbeat WebSocket

## 📋 Contexte projet

Voir [VISION.md](../shared/VISION.md) pour la description complète du projet et de ses quatre applications.

---

## 🎯 User Story

> **En tant que** maître du jeu,
> **je veux** que le serveur détecte automatiquement les connexions WebSocket silencieusement perdues (buzzers hors WiFi, réseau coupé),
> **afin de** garantir que le registre des connexions reflète en permanence l'état réel des clients connectés.

---

## ✅ Critères d'acceptance

> 🧪 **Exigence de couverture** — Voir [Conventions techniques — Couverture des tests](../shared/CONVENTIONS-TECHNIQUES.md#-exigence-de-couverture-des-tests). Chaque CA doit être couvert par au moins un test automatisé. Couverture globale ≥ 90 %.

### Démarrage et arrêt du heartbeat

| # | Critère | Résultat attendu |
|---|---|---|
| CA-1 | Le heartbeat démarre uniquement après authentification réussie d'un client | Le premier ping est envoyé 30 secondes après `auth_success` |
| CA-2 | Le heartbeat ne démarre pas pour une connexion non authentifiée | Aucun ping envoyé avant `auth_success` |
| CA-3 | À la déconnexion d'un client (quelle qu'en soit la cause), le timer heartbeat est annulé | Aucun ping envoyé après fermeture de la connexion |

### Envoi du ping et réception du pong

| # | Critère | Résultat attendu |
|---|---|---|
| CA-4 | Le serveur envoie une frame Ping RFC 6455 à chaque client authentifié toutes les 30 secondes | Frame Ping native (opcode `0x9`) envoyée via la lib `ws` |
| CA-5 | Le serveur réinitialise le compteur de pings manqués à la réception d'un Pong | Le client est considéré comme vivant, le cycle repart |
| CA-6 | Si un Pong n'est pas reçu avant le prochain Ping, le compteur de pings manqués est incrémenté | Le compteur passe de 0 à 1 (puis 2, puis 3) |

### Fermeture après pings manqués

| # | Critère | Résultat attendu |
|---|---|---|
| CA-7 | Après 3 pings consécutifs sans Pong, la connexion est fermée | Fermeture avec code `1000` (Normal Closure) |
| CA-8 | L'événement `WEBSOCKET_HEARTBEAT_TIMEOUT` est loggé en `WARN` avant la fermeture | Log émis avec `username`, `role`, `ip`, `missed_pings: 3` |
| CA-9 | Le client est retiré du registre des connexions après fermeture par heartbeat timeout | La `Map` ne contient plus l'entrée du `sub` concerné |
| CA-10 | Les compteurs `buzzers_connected` / `admin_connected` sont mis à jour après fermeture par heartbeat | Les compteurs reflètent l'état réel post-fermeture |

### Robustesse et cas limites

| # | Critère | Résultat attendu |
|---|---|---|
| CA-11 | Si la connexion est fermée normalement par le client entre deux pings, le heartbeat timeout ne se déclenche pas | Le timer est annulé lors du traitement de l'événement `close` de l'US-009 |
| CA-12 | Erreur serveur inattendue lors du heartbeat | Log `INTERNAL_ERROR` niveau `ERROR`, connexion fermée avec code `1011` |
| CA-13 | Tests unitaires et d'intégration | Couverture ≥ 90%, timers injectables pour les tests |

---

## 🔄 Flux heartbeat

```
[Après auth_success — US-009]
  → Démarrage du cycle heartbeat (intervalle : 30s)

[Toutes les 30 secondes]
  → Si missed_pings < 3
      → Envoi frame Ping RFC 6455 (opcode 0x9)
      → Incrémentation de missed_pings
  → Si missed_pings >= 3
      → Log WEBSOCKET_HEARTBEAT_TIMEOUT (WARN)
      → Fermeture connexion (code 1000)
      → Suppression du registre des connexions (délégué à US-009)

[À la réception d'un Pong (opcode 0xA)]
  → Réinitialisation de missed_pings à 0

[À la déconnexion du client — événement close US-009]
  → Annulation du timer heartbeat
```

---

## 📝 Logging structuré

### Format JSON

**Heartbeat timeout (connexion zombie détectée) :**

```json
{
  "timestamp": "2026-03-09T15:00:00.000Z",
  "level": "WARN",
  "event": "WEBSOCKET_HEARTBEAT_TIMEOUT",
  "username": "quiz_buzzer_01",
  "role": "buzzer",
  "ip": "192.168.1.50",
  "missed_pings": 3
}
```

> ⚠️ Le `WEBSOCKET_DISCONNECTED` défini dans l'US-009 **n'est pas** loggé dans ce cas. `WEBSOCKET_HEARTBEAT_TIMEOUT` le remplace et constitue la trace suffisante de la déconnexion.

---

## 📐 Périmètre

| Inclus | Exclu |
|---|---|
| Module heartbeat indépendant (SRP) | Reconnexion automatique côté client |
| Frames Ping/Pong natifs RFC 6455 (lib `ws`) | Ping applicatif JSON |
| Intervalle configurable via paramètre injecté (KISS) | Mesure et exposition de la latence RTT (YAGNI) |
| Compteur de pings manqués par connexion | Persistance du compteur en base |
| Fermeture code `1000` après 3 pings manqués | Nouveau code de fermeture custom |
| Log `WEBSOCKET_HEARTBEAT_TIMEOUT` niveau `WARN` | Log verbeux par ping/pong |
| Timers injectables pour la testabilité | Timer global partagé entre connexions |
| Tests unitaires et d'intégration (couverture ≥ 90%) | Déploiement / CI-CD |

---

## 🔧 Spécifications techniques

Voir les [Conventions techniques](../shared/CONVENTIONS-TECHNIQUES.md) pour la stack complète, les principes d'architecture (KISS, DRY, YAGNI, SOLID) et les conventions de données.

---

## 🏗️ Architecture — Intégration avec l'US-009

Le module heartbeat est une unité indépendante qui **reçoit le registre des connexions** en paramètre (injection de dépendance — DIP). Il ne duplique aucune logique de l'US-009 (DRY) et ne porte qu'une seule responsabilité (SRP) : piloter le cycle ping/pong et fermer les connexions zombies.

### Structure des fichiers

```
src/
  websocket/
    connection-registry.js    ← US-009 (Map des connexions)
    ws-connection-handler.js  ← US-009 (auth, registre, close)
    ws-heartbeat.js           ← US-015 (ping/pong, timeout) ← NOUVEAU
```

### Interface conceptuelle du module

```javascript
// Démarrage du heartbeat pour une connexion authentifiée
// Appelé par ws-connection-handler.js après auth_success
startHeartbeat(ws, connectionEntry, { intervalMs, maxMissed, setIntervalFn })

// Arrêt du heartbeat
// Appelé par ws-connection-handler.js à chaque événement close
stopHeartbeat(ws)
```

### Modification apportée à l'US-009

La seule modification du périmètre US-009 est l'ajout de deux appels dans `ws-connection-handler.js` :

- `startHeartbeat(...)` après l'envoi de `auth_success`
- `stopHeartbeat(ws)` dans le gestionnaire `close`

Aucune autre logique de l'US-009 n'est modifiée.

### Structure de l'entrée du registre enrichie

L'entrée existante dans la `Map` est complétée d'un champ `heartbeatTimer` pour permettre l'annulation propre du timer :

```javascript
// Structure enrichie (US-009 + US-015)
Map<sub (UUIDv7), {
  ws,           // Instance WebSocket active
  role,         // "buzzer" ou "admin"
  username,     // Nom d'utilisateur
  connectedAt,  // Horodatage ISO 8601 UTC
  heartbeatTimer // Référence au timer setInterval (null avant auth)
}>
```

---

## 🔍 Points de vigilance

### Frames Ping RFC 6455 et ESP32-S3

Les deux bibliothèques Arduino WebSocket couramment utilisées avec l'ESP32 sous PlatformIO supportent les frames Ping RFC 6455 et répondent automatiquement avec un Pong :

- **`Links2004/arduinoWebSockets`** : réponse Pong automatique, conforme RFC 6455.
- **`gilmaimon/ArduinoWebsockets`** : expose les événements `GotPing` / `GotPong`, réponse Pong automatique.

> ⚠️ **Prérequis firmware** — Vérifier avant intégration que la bibliothèque WebSocket embarquée dans le firmware ESP32-S3 est bien l'une de ces deux bibliothèques, et **non** l'implémentation native `esp_http_server` de l'ESP-IDF, qui présente un bug documenté de dispatching des frames Pong pouvant provoquer une fermeture de connexion intempestive.

Angular (navigateur) répond nativement aux Pings RFC 6455 sans configuration particulière.

### Annulation du timer à la déconnexion

`stopHeartbeat` doit impérativement être appelé depuis le gestionnaire `close` de l'US-009, quelle que soit la cause de la déconnexion (fermeture client, timeout auth, remplacement de session, heartbeat timeout lui-même). Une double annulation (`clearInterval` sur un timer déjà annulé) est sans effet et ne constitue pas une erreur.

### Un timer par connexion

Chaque connexion authentifiée possède son propre timer `setInterval` indépendant, stocké dans le registre. Il n'y a pas de timer global partagé entre connexions — conformément au principe KISS et à l'isolation des responsabilités.

### Testabilité des timers

La fonction `setInterval` est injectée en paramètre de `startHeartbeat` (valeur par défaut : `globalThis.setInterval`). Cela permet d'utiliser `jest.useFakeTimers()` ou un stub explicite dans les tests sans modifier le code de production, et sans recourir à un monkey-patching global.

---

## 📅 Historique des révisions

| Version | Date | Description |
|---|---|---|
| 1.0 | 2026-03-26 | Version initiale |
