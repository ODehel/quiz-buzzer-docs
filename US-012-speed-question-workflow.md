# US-012 — Workflow d'une question SPEED

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

> **En tant que** maître du jeu,
> **je veux** piloter le déroulement d'une question SPEED (affichage du titre avec chronomètre simultané, gestion du buzze, validation ou invalidation de la réponse orale),
> **afin de** animer la partie en temps réel et désigner le joueur qui répond en premier depuis son buzzer physique.

---

## ✅ Critères d'acceptance

> 🧪 **Exigence de couverture** — Chaque critère d'acceptance listé ci-dessous doit être couvert par **au moins un test automatisé** (unitaire et/ou d'intégration). Un CA non couvert par un test est considéré comme **non livré**. La couverture globale du code de l'US doit être **≥ 90%**, mesurée via `jest --coverage`.

### Machine à états de la partie — Extension pour SPEED

| # | Critère | Résultat attendu |
|---|---|---|
| CA-1 | La machine à états de la partie est étendue avec l'état `QUESTION_BUZZED` | Transitions valides : `OPEN → QUESTION_OPEN → QUESTION_BUZZED → QUESTION_OPEN` (invalidation) ou `QUESTION_BUZZED → QUESTION_CLOSED` (validation ou dernier joueur invalidé) puis `QUESTION_CLOSED → OPEN` (question suivante) ou `QUESTION_CLOSED → COMPLETED` (dernière question) |
| CA-2 | L'état courant et l'index de la question en cours sont persistés en base à chaque transition | `GAM_STATUS` et `GAM_CURRENT_QUESTION_INDEX` mis à jour |
| CA-3 | La progression est strictement linéaire et irréversible (hors cycle invalidation) | Aucune transition non documentée n'est possible |

### Déclenchement de la question SPEED — `trigger_title`

| # | Critère | Résultat attendu |
|---|---|---|
| CA-4 | Le maître du jeu envoie `trigger_title` alors que la question courante est de type `SPEED` | Le serveur détecte le type `SPEED`, saute `QUESTION_TITLE`, passe directement en `QUESTION_OPEN`, diffuse `question_open` à tous les buzzers et à Angular, et démarre le chronomètre |
| CA-5 | Le message `question_open` contient l'index de la question, le type (`SPEED`), le titre, le `time_limit` et l'horodatage de démarrage (`started_at`) | Données conformes à la question en base |
| CA-6 | `trigger_title` reçu alors que l'état n'est pas `OPEN` | Serveur envoie `error` à Angular avec code `INVALID_STATE` |
| CA-7 | `trigger_title` reçu alors qu'il n'y a plus de question disponible | Serveur envoie `error` à Angular avec code `NO_MORE_QUESTIONS` |

### Chronomètre

| # | Critère | Résultat attendu |
|---|---|---|
| CA-8 | Le serveur envoie un tick de resynchronisation `timer_tick` toutes les 5 secondes en état `QUESTION_OPEN` | Format : `{ "type": "timer_tick", "remaining_seconds": N }` |
| CA-9 | À expiration du chrono en état `QUESTION_OPEN` (aucun buzze en cours), le serveur envoie automatiquement `timer_end` à tous les buzzers et à Angular | Aucun point n'est attribué — tous les participants sont enregistrés en mémoire avec `answer: null`, `time_ms: time_limit * 1000`, `points_earned: 0` |
| CA-10 | À expiration du chrono en état `QUESTION_BUZZED` (un joueur a buzzé, le maître n'a pas encore décidé), le serveur envoie `timer_end` à Angular uniquement | Les buzzers ne reçoivent pas `timer_end` — la question reste en `QUESTION_BUZZED`, le maître doit toujours valider ou invalider |
| CA-11 | Les `timer_tick` s'arrêtent dès la réception d'un buzze (transition vers `QUESTION_BUZZED`) | Le chrono est suspendu pendant l'état `QUESTION_BUZZED` |
| CA-12 | Les `timer_tick` reprennent après invalidation (retour en `QUESTION_OPEN`) avec le temps restant au moment du buzze | Le temps consommé pendant `QUESTION_BUZZED` n'est pas décompté |

### Buzze d'un joueur — `buzz`

| # | Critère | Résultat attendu |
|---|---|---|
| CA-13 | Un buzzer envoie `buzz` en état `QUESTION_OPEN` | Le serveur enregistre le buzze en mémoire (participant, timestamp serveur, temps écoulé depuis `started_at`), passe en `QUESTION_BUZZED`, suspend le chrono |
| CA-14 | Le serveur envoie `buzz_accepted` au buzzer qui a buzzé | Format : `{ "type": "buzz_accepted" }` |
| CA-15 | Le serveur envoie `buzz_locked` à tous les autres buzzers et à Angular | Format : `{ "type": "buzz_locked", "buzzer_username": "quiz_buzzer_03" }` |
| CA-16 | Buzze reçu alors que l'état n'est pas `QUESTION_OPEN` | Serveur ignore silencieusement, log `WARN` |
| CA-17 | Buzze reçu d'un buzzer dont le participant n'appartient pas à la partie | Serveur ignore silencieusement, log `WARN` |
| CA-18 | Buzze reçu d'un buzzer déjà invalidé sur cette question | Serveur ignore silencieusement, log `WARN` |

### Validation de la réponse orale — `validate_answer`

| # | Critère | Résultat attendu |
|---|---|---|
| CA-19 | Le maître du jeu envoie `validate_answer` depuis Angular en état `QUESTION_BUZZED` | Le serveur calcule les scores, les persiste en base, diffuse les résultats, passe en `QUESTION_CLOSED` |
| CA-20 | `validate_answer` reçu alors que l'état n'est pas `QUESTION_BUZZED` | Serveur envoie `error` à Angular avec code `INVALID_STATE` |

### Invalidation de la réponse orale — `invalidate_answer`

| # | Critère | Résultat attendu |
|---|---|---|
| CA-21 | Le maître du jeu envoie `invalidate_answer` depuis Angular en état `QUESTION_BUZZED` et il reste des joueurs disponibles (non invalidés, non encore buzzés sur cette question, ou pouvant buzzer à nouveau) | Le joueur buzzeur est marqué en mémoire comme invalidé (`answer: null`, `time_ms: time_limit * 1000`, `points_earned: 0`), le serveur renvoie en `QUESTION_OPEN`, reprend le chrono, renvoie les `timer_tick` |
| CA-22 | Le serveur envoie `buzz_invalidated` au buzzer invalidé | Format : `{ "type": "buzz_invalidated" }` — le buzzer affiche un écran d'élimination pour cette question |
| CA-23 | Le serveur envoie `buzz_unlocked` à tous les buzzers non invalidés et à Angular | Format : `{ "type": "buzz_unlocked", "remaining_seconds": N }` — les buzzers non invalidés peuvent à nouveau buzzer |
| CA-24 | Le maître du jeu envoie `invalidate_answer` et il ne reste plus aucun joueur disponible (tous invalidés ou chrono expiré avant la décision) | Équivaut à une expiration : le serveur calcule les scores (0 point pour tous), persiste, diffuse les résultats, passe en `QUESTION_CLOSED` |
| CA-25 | `invalidate_answer` reçu alors que l'état n'est pas `QUESTION_BUZZED` | Serveur envoie `error` à Angular avec code `INVALID_STATE` |

### Persistance des scores

| # | Critère | Résultat attendu |
|---|---|---|
| CA-26 | À la validation de la réponse, seul le gagnant est persisté dans `T_GAME_ANSWER_GAA` | Une ligne insérée : réponse `"SPEED_WIN"`, temps de réponse en ms depuis `started_at`, points gagnés, score cumulé mis à jour |
| CA-27 | En cas d'expiration ou de dernier joueur invalidé, aucune ligne n'est insérée dans `T_GAME_ANSWER_GAA` | Aucun point attribué, scores cumulés inchangés |
| CA-28 | En cas d'erreur SQLite lors de la sauvegarde, le serveur effectue jusqu'à 3 tentatives avec délai exponentiel | Comportement identique à l'US-011 (CA-34) |
| CA-29 | Après 3 tentatives échouées, la partie passe en `IN_ERROR`, le serveur envoie `error` à Angular avec code `INTERNAL_ERROR` | Log `ERROR` avec détail technique |

### Résultats diffusés à la fin de la question

| # | Critère | Résultat attendu |
|---|---|---|
| CA-30 | Le serveur envoie `question_result` individuellement à chaque buzzer | Gagnant : `correct: true`, points gagnés, score cumulé — Invalidés : `correct: false`, `points_earned: 0`, score cumulé inchangé — Non buzzés : `correct: false`, `points_earned: 0`, score cumulé inchangé |
| CA-31 | Le serveur envoie `question_result_summary` à Angular | Contient : le gagnant (ou `null`), le détail de tous les joueurs ayant buzzé (nom, temps de réponse, statut validé/invalidé, points gagnés, score cumulé), le classement mis à jour |

### Passage à la question suivante — `trigger_next_question`

| # | Critère | Résultat attendu |
|---|---|---|
| CA-32 | Le maître du jeu envoie `trigger_next_question` depuis Angular en état `QUESTION_CLOSED` | Comportement identique à l'US-011 (CA-29, CA-30) |
| CA-33 | `trigger_next_question` reçu alors que l'état n'est pas `QUESTION_CLOSED` | Serveur envoie `error` à Angular avec code `INVALID_STATE` |

### Sécurité et transversalité

| # | Critère | Résultat attendu |
|---|---|---|
| CA-34 | Seul le client authentifié avec le rôle `admin` peut envoyer des messages de pilotage (`validate_answer`, `invalidate_answer`, `trigger_next_question`) | Buzzer envoyant un message de pilotage → ignoré silencieusement, log `WARN` |
| CA-35 | Seul un client authentifié avec le rôle `buzzer` peut envoyer `buzz` | Angular envoyant `buzz` → ignoré silencieusement, log `WARN` |
| CA-36 | Tout message reçu d'un client non authentifié est ignoré | Ignoré silencieusement, log `WARN` |
| CA-37 | Tout message avec un `type` inconnu est ignoré | Ignoré silencieusement, log `WARN` |
| CA-38 | Tout message avec un JSON invalide est ignoré | Ignoré silencieusement, log `WARN` |
| CA-39 | Tests unitaires et d'intégration | Couverture de tests ≥ 90% |

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
| Bibliothèque WebSocket | `ws` (dernière version stable disponible) |
| Chronomètre | Côté serveur (`setTimeout` / `setInterval`) |
| Principes d'architecture | YAGNI, KISS, DRY, SOLID |

> ⚠️ **Exigence fondamentale** — Toute implémentation de cette US doit scrupuleusement respecter les principes **KISS** (solutions simples), **DRY** (pas de duplication), **YAGNI** (pas de fonctionnalité prématurée) et **SOLID** (architecture modulaire et responsabilités séparées). Ces principes prévalent sur toute optimisation prématurée ou généralisation non justifiée par un besoin immédiat documenté.

### Extension du schéma de la table `T_GAME_GAM`

La contrainte `CHECK` sur `GAM_STATUS` est étendue pour intégrer `QUESTION_BUZZED` :

```sql
-- La migration doit recréer T_GAME_GAM avec la contrainte étendue (SQLite ne supporte pas ALTER COLUMN)
-- Nouveaux états autorisés (s'ajoutent à ceux définis dans US-011) :
CHECK (GAM_STATUS IN (
    'PENDING',
    'OPEN',
    'QUESTION_TITLE',
    'QUESTION_OPEN',
    'QUESTION_BUZZED',
    'QUESTION_CLOSED',
    'COMPLETED',
    'IN_ERROR'
))
```

> **Note :** `QUESTION_TITLE` reste dans la contrainte pour compatibilité avec les questions MCQ (US-011). Il n'est jamais utilisé par les questions SPEED.

### Machine à états complète (MCQ + SPEED)

```
PENDING
  └─► OPEN
        │
        ├─► [question MCQ] QUESTION_TITLE → QUESTION_OPEN → QUESTION_CLOSED
        │
        └─► [question SPEED] QUESTION_OPEN ⇄ QUESTION_BUZZED → QUESTION_CLOSED
                                                                       │
                                                          ├─► OPEN  (question suivante)
                                                          └─► COMPLETED (dernière question)

IN_ERROR ← depuis tout état en cas d'erreur SQLite après 3 tentatives
```

| Transition | Déclencheur | Condition |
|---|---|---|
| `OPEN → QUESTION_OPEN` | `trigger_title` (admin) — question SPEED détectée | Questions restantes disponibles |
| `QUESTION_OPEN → QUESTION_BUZZED` | `buzz` (buzzer) | État = `QUESTION_OPEN`, joueur éligible |
| `QUESTION_BUZZED → QUESTION_OPEN` | `invalidate_answer` (admin) | Joueurs disponibles restants |
| `QUESTION_BUZZED → QUESTION_CLOSED` | `validate_answer` (admin) | État = `QUESTION_BUZZED` |
| `QUESTION_BUZZED → QUESTION_CLOSED` | `invalidate_answer` (admin) | Plus aucun joueur disponible |
| `QUESTION_OPEN → QUESTION_CLOSED` | Expiration chrono (serveur) | État = `QUESTION_OPEN`, aucun buzze en cours |
| `QUESTION_CLOSED → OPEN` | `trigger_next_question` (admin) | Questions restantes disponibles |
| `QUESTION_CLOSED → COMPLETED` | `trigger_next_question` (admin) | Dernière question atteinte |
| `* → IN_ERROR` | Serveur | Échec SQLite après 3 tentatives |

### État en mémoire pendant une question SPEED

```javascript
// Structure conceptuelle — réinitialisée à chaque nouvelle question
{
  startedAt: "2026-03-17T14:30:00.000Z",   // horodatage du trigger_title
  currentBuzzer: { sub, username, timeMsAtBuzz },  // null si QUESTION_OPEN
  invalidated: Set<sub>,                    // buzzers invalidés sur cette question
  timerExpiredDuringBuzz: false             // true si timer_end reçu en QUESTION_BUZZED
}
```

### Chronomètre — Comportement en QUESTION_BUZZED

```
trigger_title reçu (question SPEED)
  → Démarrage setInterval (tick/5s) + setTimeout (expiration)
  → Diffusion question_open { started_at, time_limit }

buzz reçu
  → clearInterval (tick suspendu)
  → clearTimeout (expiration suspendue)
  → Mémorisation du temps restant (remaining_ms)
  → Transition QUESTION_BUZZED

    Si timer_end se produit pendant QUESTION_BUZZED (race condition) :
      → timerExpiredDuringBuzz = true
      → Envoi timer_end à Angular uniquement
      → Le serveur attend toujours la décision du maître

validate_answer reçu
  → Persistance + résultats + QUESTION_CLOSED
  → (pas de reprise chrono nécessaire)

invalidate_answer reçu, joueurs disponibles restants
  → Reprise setInterval + setTimeout avec remaining_ms
  → Transition QUESTION_OPEN

invalidate_answer reçu, plus aucun joueur disponible OU timerExpiredDuringBuzz = true
  → Clôture immédiate → QUESTION_CLOSED (0 point pour tous)
```

### Détection du type de question dans `trigger_title`

Le serveur résout le type de la question courante via `GAM_CURRENT_QUESTION_INDEX` et la jointure avec `T_QUIZ_QUESTION_QQN` + `T_QUESTION_QST`. Si `QST_TYPE = 'SPEED'`, le serveur saute `QUESTION_TITLE` et passe directement en `QUESTION_OPEN`. Angular n'a pas besoin de connaître le type — il envoie toujours `trigger_title`.

### Format des messages WebSocket

**Pilotage — Angular → Serveur**

```json
{ "type": "trigger_title" }
{ "type": "validate_answer" }
{ "type": "invalidate_answer" }
{ "type": "trigger_next_question" }
```

**Buzze — Buzzer → Serveur**

```json
{ "type": "buzz" }
```

**Diffusion — Serveur → Tous (buzzers + Angular)**

```json
{
  "type": "question_open",
  "question_index": 2,
  "question_type": "SPEED",
  "title": "Quel est le plus grand océan du monde ?",
  "started_at": "2026-03-17T14:30:00.000Z",
  "time_limit": 15
}
```

```json
{ "type": "timer_tick", "remaining_seconds": 10 }
```

```json
{ "type": "timer_end" }
```

**Accusé buzze — Serveur → Buzzer buzzeur uniquement**

```json
{ "type": "buzz_accepted" }
```

**Blocage — Serveur → Autres buzzers + Angular**

```json
{ "type": "buzz_locked", "buzzer_username": "quiz_buzzer_03" }
```

**Invalidation — Serveur → Buzzer invalidé**

```json
{ "type": "buzz_invalidated" }
```

**Déblocage — Serveur → Buzzers non invalidés + Angular**

```json
{ "type": "buzz_unlocked", "remaining_seconds": 8 }
```

**Résultat individuel — Serveur → Chaque buzzer**

Gagnant :
```json
{
  "type": "question_result",
  "correct": true,
  "points_earned": 20,
  "cumulative_score": 55
}
```

Invalidé ou non buzzé :
```json
{
  "type": "question_result",
  "correct": false,
  "points_earned": 0,
  "cumulative_score": 35
}
```

**Résultat complet — Serveur → Angular**

```json
{
  "type": "question_result_summary",
  "winner": {
    "participant_order": 3,
    "participant_name": "Charlie",
    "time_ms": 4100,
    "points_earned": 20,
    "cumulative_score": 55
  },
  "buzzers": [
    {
      "participant_order": 1,
      "participant_name": "Alice",
      "status": "invalidated",
      "time_ms": 15000,
      "points_earned": 0,
      "cumulative_score": 45
    },
    {
      "participant_order": 3,
      "participant_name": "Charlie",
      "status": "winner",
      "time_ms": 4100,
      "points_earned": 20,
      "cumulative_score": 55
    }
  ],
  "ranking": [
    { "rank": 1, "participant_name": "Charlie", "cumulative_score": 55, "total_time_ms": 4100 },
    { "rank": 2, "participant_name": "Alice", "cumulative_score": 45, "total_time_ms": 23300 },
    { "rank": 3, "participant_name": "Bob", "cumulative_score": 25, "total_time_ms": 12400 }
  ]
}
```

> **Note :** `buzzers` ne contient que les joueurs ayant effectivement buzzé. Les joueurs n'ayant pas buzzé n'apparaissent pas dans ce tableau (ils apparaissent uniquement dans `ranking`).

**Erreurs — Serveur → Client émetteur**

```json
{
  "type": "error",
  "code": "INVALID_STATE",
  "message": "This action is not allowed in the current game state."
}
```

### Catalogue des codes d'erreur WebSocket

| Code | Contexte |
|---|---|
| `INVALID_STATE` | Transition d'état non autorisée depuis l'état courant |
| `NO_MORE_QUESTIONS` | `trigger_title` reçu alors que toutes les questions ont été jouées |
| `INVALID_MESSAGE` | Message avec champs manquants ou invalides |
| `INTERNAL_ERROR` | Erreur SQLite après 3 tentatives — partie passée en `IN_ERROR` |

### Structure des fichiers

```
src/
  game/
    gameWorkflow.js            ← étendu : gestion des transitions SPEED + détection du type
    gameTimer.js               ← étendu : suspension/reprise du chrono (QUESTION_BUZZED)
    gameSpeedProcessor.js      ← traitement des buzzes, validation, invalidation, état mémoire SPEED
  game/__tests__/
    gameWorkflow.test.js       ← étendu
    gameTimer.test.js          ← étendu
    gameSpeedProcessor.test.js ← nouveau
```

---

## 📝 Logging structuré

**Buzze reçu :**

```json
{
  "timestamp": "2026-03-17T14:30:04.000Z",
  "level": "INFO",
  "event": "GAME_BUZZ_RECEIVED",
  "game_id": "018e4f5d-0000-7000-8000-000000000001",
  "question_index": 2,
  "participant_order": 3,
  "time_ms": 4100
}
```

**Buzze ignoré :**

```json
{
  "timestamp": "2026-03-17T14:30:04.500Z",
  "level": "WARN",
  "event": "GAME_BUZZ_IGNORED",
  "reason": "Already invalidated",
  "participant_order": 1,
  "game_id": "018e4f5d-0000-7000-8000-000000000001"
}
```

**Transition d'état :**

```json
{
  "timestamp": "2026-03-17T14:30:04.000Z",
  "level": "INFO",
  "event": "GAME_QUESTION_STATE_CHANGED",
  "game_id": "018e4f5d-0000-7000-8000-000000000001",
  "question_index": 2,
  "new_status": "QUESTION_BUZZED"
}
```

**Timer expiré pendant QUESTION_BUZZED :**

```json
{
  "timestamp": "2026-03-17T14:30:15.000Z",
  "level": "INFO",
  "event": "GAME_TIMER_EXPIRED_DURING_BUZZ",
  "game_id": "018e4f5d-0000-7000-8000-000000000001",
  "question_index": 2,
  "participant_order": 3
}
```

---

## 📐 Périmètre

| Inclus | Exclu |
|---|---|
| Machine à états SPEED (`QUESTION_OPEN` ⇄ `QUESTION_BUZZED` → `QUESTION_CLOSED`) | Workflow MCQ (US-011) |
| Détection automatique du type de question dans `trigger_title` | Classement intermédiaire à la demande (US dédiée) |
| Suspension et reprise du chronomètre lors d'un buzze | Upload et gestion des fichiers médias des questions |
| Gestion des buzzes (acceptation, blocage, invalidation successive) | Interface Angular (hors périmètre serveur) |
| Validation et invalidation de la réponse orale par le maître du jeu | Firmware ESP32-S3 |
| Persistance du gagnant uniquement dans `T_GAME_ANSWER_GAA` | Déploiement / CI-CD |
| Résultats individuels par buzzer et résumé complet Angular | |
| Retry x3 sur erreur SQLite avant passage en `IN_ERROR` | |
| Tests unitaires et d'intégration (couverture ≥ 90%) | |

---

## 🔍 Points de vigilance

### Détection du type de question dans `trigger_title`

La détection du type est effectuée côté serveur lors de la réception de `trigger_title`. Angular envoie toujours le même message, quelle que soit le type de question. C'est le serveur qui adapte le flux (saut de `QUESTION_TITLE` pour SPEED). Cette logique appartient à `gameWorkflow.js` (SRP).

### Race condition buzze / expiration chrono

Identique à la race condition MCQ (réponse / expiration), mais avec une asymétrie : si le chrono expire pendant `QUESTION_BUZZED`, le serveur attend la décision du maître avant de clore la question. Le flag `timerExpiredDuringBuzz` est mémorisé pour que le serveur clôture immédiatement après la prochaine décision du maître (validation ou invalidation).

### Suspension et reprise du chrono

Le chrono est suspendu (clearInterval + clearTimeout) dès le buzze. La valeur `remaining_ms` est mémorisée en mémoire. À la reprise (après invalidation), de nouveaux setInterval et setTimeout sont créés avec `remaining_ms`. Cette logique est isolée dans `gameTimer.js` (SRP).

### Joueurs disponibles après invalidation

Un joueur est considéré "disponible" s'il n'a pas encore été invalidé sur cette question. Il n'y a pas de limite au nombre de cycles buzze/invalidation, hormis le nombre de joueurs et le temps imparti. La liste des joueurs invalidés est maintenue dans un `Set<sub>` en mémoire, réinitialisé à chaque nouvelle question.

### Cohérence MCQ / SPEED dans `T_GAME_ANSWER_GAA`

En MCQ, une ligne est insérée pour chaque participant. En SPEED, une seule ligne est insérée (le gagnant uniquement). Cette asymétrie est intentionnelle (YAGNI) et documentée dans les spécifications de persistance. Les requêtes de classement doivent en tenir compte : l'absence de ligne en SPEED ne signifie pas que le score cumulé est nul, mais que la question s'est terminée sans gagnant ou que seul le gagnant est enregistré.

### Extension de la contrainte CHECK sur `GAM_STATUS`

Comme pour US-011, SQLite ne supporte pas `ALTER COLUMN`. La migration doit recréer `T_GAME_GAM` avec la contrainte `CHECK` étendue (ajout de `QUESTION_BUZZED`), migrer les données existantes, puis supprimer l'ancienne table — dans une transaction atomique.

### Réutilisation du registre de connexions (US-009)

Le registre `Map<sub, { ws, role, username, connectedAt }>` est utilisé pour identifier l'émetteur des messages `buzz`, `validate_answer`, `invalidate_answer`, diffuser les messages ciblés (`buzz_accepted`, `buzz_locked`, `buzz_invalidated`, `buzz_unlocked`, `question_result`) et résoudre le `participant_order` à partir du `username` pour la persistance. Aucune logique de registre n'est dupliquée dans cette US (DRY).
