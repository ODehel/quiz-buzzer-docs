![Page de couverture — US-011](diagrams/covers/US-011-cover.png)

# US-011 — Workflow d'une question MCQ

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
> **je veux** piloter le déroulement d'une question MCQ étape par étape (affichage du titre, affichage des propositions avec chronomètre, affichage de la correction),
> **afin de** animer la partie en temps réel et permettre à chaque joueur de répondre depuis son buzzer.

---

## ✅ Critères d'acceptance

> 🧪 **Exigence de couverture** — Chaque critère d'acceptance listé ci-dessous doit être couvert par **au moins un test automatisé** (unitaire et/ou d'intégration). Un CA non couvert par un test est considéré comme **non livré**. La couverture globale du code de l'US doit être **≥ 90%**, mesurée via `jest --coverage`.

### Machine à états de la partie

| # | Critère | Résultat attendu |
|---|---|---|
| CA-1 | La machine à états complète de la partie est étendue avec les nouveaux états | Transitions valides : `PENDING → OPEN → QUESTION_TITLE → QUESTION_OPEN → QUESTION_CLOSED → OPEN` (question suivante) ou `QUESTION_CLOSED → COMPLETED` (dernière question) |
| CA-2 | L'état courant de la partie et l'index de la question en cours sont persistés en base | `GAM_STATUS` et `GAM_CURRENT_QUESTION_INDEX` mis à jour à chaque transition |
| CA-3 | La progression est strictement linéaire et irréversible | Aucune transition vers un état précédent n'est possible |

### Déclenchement du titre — `trigger_title`

| # | Critère | Résultat attendu |
|---|---|---|
| CA-4 | Le maître du jeu envoie `trigger_title` depuis Angular | La partie passe en `QUESTION_TITLE`, le serveur diffuse `question_title` à tous les buzzers et à Angular |
| CA-5 | Le message `question_title` contient l'index de la question, le type (`MCQ`), le titre et le `time_limit` | Données conformes à la question en base |
| CA-6 | `trigger_title` reçu alors que l'état n'est pas `OPEN` | Serveur envoie `error` à Angular avec code `INVALID_STATE` |
| CA-7 | `trigger_title` reçu alors qu'il n'y a plus de question disponible (index hors limites) | Serveur envoie `error` à Angular avec code `NO_MORE_QUESTIONS` |

### Déclenchement des propositions — `trigger_choices`

| # | Critère | Résultat attendu |
|---|---|---|
| CA-8 | Le maître du jeu envoie `trigger_choices` depuis Angular | La partie passe en `QUESTION_OPEN`, le serveur diffuse `question_choices` à tous les buzzers et à Angular, le chronomètre démarre |
| CA-9 | Le message `question_choices` contient les 4 propositions A/B/C/D, l'horodatage de démarrage du chrono (`started_at`) et la durée (`time_limit`) | Données conformes à la question en base |
| CA-10 | Le serveur envoie un tick de resynchronisation `timer_tick` toutes les 5 secondes avec le temps restant | Format : `{ "type": "timer_tick", "remaining_seconds": N }` |
| CA-11 | À expiration du chrono, le serveur envoie automatiquement `timer_end` à tous les buzzers et à Angular | Le message indique que le temps est écoulé — les joueurs n'ayant pas répondu sont enregistrés avec `time_limit` comme temps de réponse |
| CA-12 | `trigger_choices` reçu alors que l'état n'est pas `QUESTION_TITLE` | Serveur envoie `error` à Angular avec code `INVALID_STATE` |

### Réponse d'un buzzer — `answer`

| # | Critère | Résultat attendu |
|---|---|---|
| CA-13 | Un buzzer envoie `answer` avec une valeur `A`, `B`, `C` ou `D` en état `QUESTION_OPEN` | Le serveur enregistre la réponse en mémoire, accuse réception au buzzer (`answer_received`), notifie Angular en temps réel (`player_answered`) |
| CA-14 | Le message `answer_received` envoyé au buzzer confirme la prise en compte de sa réponse | Format : `{ "type": "answer_received" }` |
| CA-15 | Le message `player_answered` envoyé à Angular contient le nom du participant, sa réponse et son temps de réponse | Permet au maître du jeu de voir les réponses en direct avec le chrono |
| CA-16 | Quand tous les joueurs connectés ont répondu, le serveur notifie Angular via `all_answered` | Le maître du jeu peut alors déclencher la correction sans attendre la fin du chrono |
| CA-17 | Réponse reçue alors que l'état n'est pas `QUESTION_OPEN` | Serveur ignore silencieusement, log `WARN` |
| CA-18 | Deuxième réponse d'un même buzzer pour la même question | Serveur ignore silencieusement, log `WARN` |
| CA-19 | Valeur de réponse invalide (ni `A`, `B`, `C`, ni `D`) | Serveur ignore silencieusement, log `WARN` |
| CA-20 | Réponse reçue après expiration du chrono (race condition : message en transit au moment de l'expiration) | Serveur ignore silencieusement, log `WARN` — le `timer_end` serveur fait foi |
| CA-21 | Un buzzer dont le participant n'appartient pas à la partie envoie une réponse | Serveur ignore silencieusement, log `WARN` |

### Déclenchement de la correction — `trigger_correction`

| # | Critère | Résultat attendu |
|---|---|---|
| CA-22 | Le maître du jeu envoie `trigger_correction` depuis Angular | Condition : tous les joueurs ont répondu **ou** le chrono est expiré — sinon `error` avec code `ANSWERS_PENDING` |
| CA-23 | Le serveur calcule les scores, les persiste en base et diffuse les résultats | Voir section Persistance |
| CA-24 | Le serveur envoie `question_result` individuellement à chaque buzzer | Contient : la bonne réponse, la réponse du joueur, un indicateur `correct` (booléen), les points gagnés sur la question, le score cumulé du joueur |
| CA-25 | Le serveur envoie `question_result_summary` à Angular | Contient : la bonne réponse, le détail complet de tous les joueurs (nom, réponse, temps de réponse, points gagnés, score cumulé), le classement mis à jour |
| CA-26 | La partie passe en `QUESTION_CLOSED` | `GAM_STATUS` mis à jour en base |
| CA-27 | `trigger_correction` reçu alors que l'état n'est pas `QUESTION_OPEN` | Serveur envoie `error` à Angular avec code `INVALID_STATE` |
| CA-28 | `trigger_correction` reçu alors que le chrono tourne encore et qu'au moins un joueur n'a pas répondu | Serveur envoie `error` à Angular avec code `ANSWERS_PENDING` |

### Passage à la question suivante — `trigger_next_question`

| # | Critère | Résultat attendu |
|---|---|---|
| CA-29 | Le maître du jeu envoie `trigger_next_question` depuis Angular | Si questions restantes : `GAM_CURRENT_QUESTION_INDEX` incrémenté, partie repasse en `OPEN` |
| CA-30 | Si c'était la dernière question, la partie passe en `COMPLETED` | `GAM_STATUS` mis à jour en base à `COMPLETED` |
| CA-31 | `trigger_next_question` reçu alors que l'état n'est pas `QUESTION_CLOSED` | Serveur envoie `error` à Angular avec code `INVALID_STATE` |

### Persistance des scores

| # | Critère | Résultat attendu |
|---|---|---|
| CA-32 | À la fin de chaque question (déclenchement de la correction), les données sont sauvegardées en base pour chaque participant | Réponse donnée, temps de réponse (ms), points gagnés sur la question, score cumulé mis à jour |
| CA-33 | Les joueurs n'ayant pas répondu avant expiration sont enregistrés avec `answer: null`, `time_ms: time_limit * 1000`, `points_earned: 0` | Score cumulé inchangé |
| CA-34 | En cas d'erreur SQLite lors de la sauvegarde, le serveur effectue jusqu'à 3 tentatives | Délai exponentiel entre les tentatives |
| CA-35 | Après 3 tentatives échouées, la partie passe en `IN_ERROR`, le serveur envoie `error` à Angular avec code `INTERNAL_ERROR` | Log `ERROR` avec détail technique |
| CA-36 | En cas de crash serveur en cours de question (état `QUESTION_TITLE` ou `QUESTION_OPEN`), la reprise repart de la dernière question complètement terminée | La question interrompue est rejouée depuis `OPEN` |

### Sécurité et transversalité

| # | Critère | Résultat attendu |
|---|---|---|
| CA-37 | Seul le client authentifié avec le rôle `admin` peut envoyer des messages de pilotage | Buzzer envoyant un message de pilotage → ignoré silencieusement, log `WARN` |
| CA-38 | Seul un client authentifié avec le rôle `buzzer` peut envoyer `answer` | Angular envoyant `answer` → ignoré silencieusement, log `WARN` |
| CA-39 | Tout message reçu d'un client non authentifié est ignoré | Ignoré silencieusement, log `WARN` |
| CA-40 | Tout message avec un `type` inconnu est ignoré | Ignoré silencieusement, log `WARN` |
| CA-41 | Tout message avec un JSON invalide est ignoré | Ignoré silencieusement, log `WARN` |
| CA-42 | Tout message avec des champs manquants ou invalides | Serveur envoie `error` au client émetteur avec code `INVALID_MESSAGE` |
| CA-43 | Tests unitaires et d'intégration | Couverture de tests ≥ 90% |

---

## 🔄 Diagramme de flux

![Diagramme de flux — US-011 — Workflow d'une question MCQ](diagrams/US-011-mcq-question-workflow.png)

---

## 🔀 Diagramme de séquences

![Diagramme de séquences — US-011 — Workflow d'une question MCQ](diagrams/US-011-mcq-question-workflow-sequence.png)

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

Deux colonnes sont ajoutées à la table existante `T_GAME_GAM` (définie dans l'US-010) :

```sql
ALTER TABLE T_GAME_GAM ADD COLUMN GAM_CURRENT_QUESTION_INDEX INTEGER NOT NULL DEFAULT 0;
ALTER TABLE T_GAME_GAM ADD COLUMN GAM_STATUS TEXT NOT NULL DEFAULT 'PENDING'
    CHECK (GAM_STATUS IN (
        'PENDING',
        'OPEN',
        'QUESTION_TITLE',
        'QUESTION_OPEN',
        'QUESTION_CLOSED',
        'COMPLETED',
        'IN_ERROR'
    ));
```

> **Note :** La contrainte `CHECK` sur `GAM_STATUS` est étendue pour intégrer les nouveaux états. La migration doit recréer la table avec la nouvelle contrainte (SQLite ne supporte pas `ALTER COLUMN`).

### Nouvelle table — Résultats par question

```sql
CREATE TABLE IF NOT EXISTS T_GAME_ANSWER_GAA
(
    GAA_ID           TEXT    PRIMARY KEY,
    GAA_GAME_ID      TEXT    NOT NULL REFERENCES T_GAME_GAM (GAM_ID) ON DELETE CASCADE,
    GAA_QUESTION_ID  TEXT    NOT NULL REFERENCES T_QUESTION_QST (QST_ID),
    GAA_PARTICIPANT_ORDER INTEGER NOT NULL,
    GAA_ANSWER       TEXT    DEFAULT NULL,
    GAA_TIME_MS      INTEGER NOT NULL,
    GAA_POINTS_EARNED INTEGER NOT NULL DEFAULT 0,
    GAA_CUMULATIVE_SCORE INTEGER NOT NULL DEFAULT 0,
    GAA_CREATED_AT   TEXT    NOT NULL,
    UNIQUE (GAA_GAME_ID, GAA_QUESTION_ID, GAA_PARTICIPANT_ORDER)
);
```

### Machine à états complète

```
PENDING
  └─► OPEN
        └─► QUESTION_TITLE       (trigger_title)
              └─► QUESTION_OPEN  (trigger_choices + démarrage chrono)
                    └─► QUESTION_CLOSED  (trigger_correction)
                          ├─► OPEN           (trigger_next_question — questions restantes)
                          └─► COMPLETED      (trigger_next_question — dernière question)

IN_ERROR  ← depuis tout état en cas d'erreur SQLite après 3 tentatives
```

| Transition | Déclencheur | Condition |
|---|---|---|
| `OPEN → QUESTION_TITLE` | `trigger_title` (admin) | Questions restantes disponibles |
| `QUESTION_TITLE → QUESTION_OPEN` | `trigger_choices` (admin) | État = `QUESTION_TITLE` |
| `QUESTION_OPEN → QUESTION_CLOSED` | `trigger_correction` (admin) | Tous ont répondu **ou** chrono expiré |
| `QUESTION_CLOSED → OPEN` | `trigger_next_question` (admin) | Questions restantes disponibles |
| `QUESTION_CLOSED → COMPLETED` | `trigger_next_question` (admin) | Dernière question atteinte |
| `* → IN_ERROR` | Serveur | Échec SQLite après 3 tentatives |

### Chronomètre — Approche hybride

```
trigger_choices reçu
  → 1. Démarrage setInterval (tick toutes les 5s) + setTimeout (expiration)
  → 2. Diffusion question_choices avec { started_at, time_limit }
       Les clients calculent le temps restant localement pour l'affichage
  → 3. Toutes les 5s : diffusion timer_tick { remaining_seconds }
       Les clients corrigent leur dérive locale
  → 4a. timer_end déclenché par le serveur à expiration
  → 4b. OU : trigger_correction reçu avant expiration (tous les joueurs ont répondu)
        → clearInterval + clearTimeout
```

### Traitement atomique des réponses (race condition)

Les réponses des buzzers et l'expiration du chrono sont traitées de manière atomique via une **file de traitement synchrone** en mémoire. Une réponse reçue dans la même boucle d'événement que `timer_end` est :
- **Acceptée** si elle est traitée avant `timer_end`
- **Rejetée** si `timer_end` a déjà été traité

### Format des messages WebSocket

**Pilotage — Angular → Serveur**

```json
{ "type": "trigger_title" }
{ "type": "trigger_choices" }
{ "type": "trigger_correction" }
{ "type": "trigger_next_question" }
```

**Diffusion — Serveur → Buzzers + Angular**

```json
{
  "type": "question_title",
  "question_index": 0,
  "question_type": "MCQ",
  "title": "Quelle est la capitale de la France ?",
  "time_limit": 30
}
```

```json
{
  "type": "question_choices",
  "choices": ["Paris", "Lyon", "Marseille", "Toulouse"],
  "started_at": "2026-03-17T14:30:00.000Z",
  "time_limit": 30
}
```

```json
{ "type": "timer_tick", "remaining_seconds": 25 }
```

```json
{ "type": "timer_end" }
```

**Réponse buzzer — Buzzer → Serveur**

```json
{ "type": "answer", "value": "A" }
```

**Accusé de réception — Serveur → Buzzer**

```json
{ "type": "answer_received" }
```

**Notification temps réel — Serveur → Angular**

```json
{
  "type": "player_answered",
  "participant_order": 2,
  "participant_name": "Bob",
  "answer": "A",
  "time_ms": 4230
}
```

```json
{ "type": "all_answered" }
```

**Résultat individuel — Serveur → Buzzer (individuel)**

```json
{
  "type": "question_result",
  "correct_answer": "A",
  "player_answer": "A",
  "correct": true,
  "points_earned": 10,
  "cumulative_score": 35
}
```

**Résultat complet — Serveur → Angular**

```json
{
  "type": "question_result_summary",
  "correct_answer": "A",
  "results": [
    {
      "participant_order": 1,
      "participant_name": "Alice",
      "answer": "A",
      "time_ms": 3100,
      "correct": true,
      "points_earned": 10,
      "cumulative_score": 45
    },
    {
      "participant_order": 2,
      "participant_name": "Bob",
      "answer": "C",
      "time_ms": 5200,
      "correct": false,
      "points_earned": 0,
      "cumulative_score": 25
    },
    {
      "participant_order": 3,
      "participant_name": "Charlie",
      "answer": null,
      "time_ms": 30000,
      "correct": false,
      "points_earned": 0,
      "cumulative_score": 30
    }
  ],
  "ranking": [
    { "rank": 1, "participant_name": "Alice", "cumulative_score": 45, "total_time_ms": 8300 },
    { "rank": 2, "participant_name": "Charlie", "cumulative_score": 30, "total_time_ms": 45000 },
    { "rank": 3, "participant_name": "Bob", "cumulative_score": 25, "total_time_ms": 12400 }
  ]
}
```

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
| `ANSWERS_PENDING` | `trigger_correction` reçu alors que le chrono tourne et qu'au moins un joueur n'a pas répondu |
| `INVALID_MESSAGE` | Message avec champs manquants ou invalides |
| `INTERNAL_ERROR` | Erreur SQLite après 3 tentatives — partie passée en `IN_ERROR` |

### Versioning API

```
Base URL WebSocket : ws://<ip>:<port>/ws
```

### Structure des fichiers

```
src/
  game/
    gameWorkflow.js          ← machine à états, orchestration du workflow MCQ
    gameTimer.js             ← gestion du chronomètre hybride (tick + expiration)
    gameAnswerProcessor.js   ← traitement atomique des réponses
  game/__tests__/
    gameWorkflow.test.js
    gameTimer.test.js
    gameAnswerProcessor.test.js
  repositories/
    gameAnswerRepository.js  ← CRUD T_GAME_ANSWER_GAA
  repositories/__tests__/
    gameAnswerRepository.test.js
```

---

## 📝 Logging structuré

### Format JSON

**Déclenchement d'une étape de question :**

```json
{
  "timestamp": "2026-03-17T14:30:00.000Z",
  "level": "INFO",
  "event": "GAME_QUESTION_STATE_CHANGED",
  "game_id": "018e4f5d-0000-7000-8000-000000000001",
  "question_index": 0,
  "new_status": "QUESTION_OPEN"
}
```

**Réponse ignorée (doublon, hors état, race condition) :**

```json
{
  "timestamp": "2026-03-17T14:30:05.000Z",
  "level": "WARN",
  "event": "GAME_ANSWER_IGNORED",
  "reason": "Duplicate answer",
  "participant_order": 2,
  "game_id": "018e4f5d-0000-7000-8000-000000000001"
}
```

**Scores persistés :**

```json
{
  "timestamp": "2026-03-17T14:30:32.000Z",
  "level": "INFO",
  "event": "GAME_QUESTION_SCORES_SAVED",
  "game_id": "018e4f5d-0000-7000-8000-000000000001",
  "question_index": 0,
  "participants_count": 3
}
```

**Erreur de persistance :**

```json
{
  "timestamp": "2026-03-17T14:30:33.000Z",
  "level": "ERROR",
  "event": "GAME_SCORES_SAVE_FAILED",
  "game_id": "018e4f5d-0000-7000-8000-000000000001",
  "attempt": 3,
  "error": "SQLITE_BUSY"
}
```

---

## 🔌 Architecture WebSocket — Workflow MCQ

### Flux complet d'une question MCQ

```
[Angular] trigger_title
  → Serveur : OPEN → QUESTION_TITLE
  → Broadcast question_title (tous buzzers + Angular)

[Angular] trigger_choices
  → Serveur : QUESTION_TITLE → QUESTION_OPEN
  → Broadcast question_choices (tous buzzers + Angular)
  → Démarrage chrono hybride (tick/5s + expiration)

[Buzzers] answer { value: "A"|"B"|"C"|"D" }
  → Serveur : validation (état, doublon, appartenance)
  → answer_received → buzzer émetteur
  → player_answered → Angular
  → Si tous ont répondu → all_answered → Angular

[Serveur] timer_end (expiration) OU [Angular] trigger_correction (tous ont répondu)
  → Serveur : QUESTION_OPEN → QUESTION_CLOSED
  → Calcul + persistance des scores (3 tentatives)
  → question_result → chaque buzzer individuellement
  → question_result_summary → Angular

[Angular] trigger_next_question
  → Questions restantes → QUESTION_CLOSED → OPEN
  → Dernière question → QUESTION_CLOSED → COMPLETED
```

### Réutilisation de l'US-009

Le registre des connexions WebSocket (`Map<sub, { ws, role, username, connectedAt }>`) défini dans l'US-009 est utilisé directement pour :
- Identifier l'émetteur de chaque message (rôle `admin` ou `buzzer`)
- Diffuser les messages aux buzzers participants
- Envoyer les résultats individuellement à chaque buzzer

---

## 📐 Périmètre

| Inclus | Exclu |
|---|---|
| Machine à états complète de la partie (tous les états MCQ) | Workflow SPEED (US dédiée — US-012) |
| Pilotage WebSocket par le maître du jeu (4 messages) | Classement intermédiaire à la demande (US dédiée) |
| Réception et validation des réponses A/B/C/D | Upload et gestion des fichiers médias des questions |
| Chronomètre hybride côté serveur (tick/5s + expiration) | Interface Angular (hors périmètre serveur) |
| Notification temps réel des réponses vers Angular | Firmware ESP32-S3 |
| Résultats individuels par buzzer et résumé complet Angular | Déploiement / CI-CD |
| Persistance des réponses et scores (T_GAME_ANSWER_GAA) | |
| Retry x3 sur erreur SQLite avant passage en IN_ERROR | |
| Reprise après crash à la dernière question terminée | |
| Gestion complète des cas d'erreur (E-01 à E-21) | |
| Tests unitaires et d'intégration (couverture ≥ 90%) | |

---

## 🔍 Points de vigilance

### Race condition réponse / expiration chrono

Le serveur Node.js est mono-thread mais la boucle d'événements peut traiter un message `answer` et le callback `timer_end` dans le même cycle. Une **file de traitement synchrone** garantit qu'une réponse est soit acceptée avant l'expiration, soit rejetée après. Le timestamp serveur de réception du message `answer` est comparé au timestamp d'expiration du chrono pour trancher les cas limites.

### Traitement atomique de la persistance

La sauvegarde des scores en fin de question implique plusieurs écritures en base (`T_GAME_ANSWER_GAA` + `T_GAME_GAM`). Ces écritures doivent être effectuées dans une **transaction SQLite atomique**. En cas d'échec, la transaction est rollbackée avant le retry suivant.

### Extension de la contrainte CHECK sur GAM_STATUS

SQLite ne supporte pas `ALTER COLUMN`. La migration doit recréer `T_GAME_GAM` avec la nouvelle contrainte `CHECK` étendue, migrer les données existantes, puis supprimer l'ancienne table. Cette opération doit être effectuée dans une transaction atomique.

### Buzzers non connectés en cours de partie

Un participant dont le buzzer n'est plus connecté (déconnexion définitive après 3 tentatives, définie dans l'US-009) est traité comme n'ayant pas répondu : `answer: null`, `time_ms: time_limit * 1000`, `points_earned: 0`. Son absence ne bloque pas le déclenchement de la correction — le maître du jeu peut toujours déclencher `trigger_correction` dès que le chrono expire ou que les joueurs connectés ont tous répondu.

### Unicité de la partie active

Étant donné qu'une seule partie peut être en état actif à la fois (contrainte de l'US-010), le serveur n'a pas besoin de l'`id` de la partie dans les messages WebSocket de pilotage — il résout directement la partie active via `SELECT ... WHERE GAM_STATUS NOT IN ('COMPLETED', 'IN_ERROR')`.

### Middlewares réutilisables (DRY / SOLID)

Le registre de connexions et les mécanismes d'authentification WebSocket définis dans l'US-009 sont réutilisés tels quels. Aucune logique d'authentification n'est dupliquée dans cette US. La vérification du rôle (`admin` vs `buzzer`) est effectuée via une consultation du registre existant.

### Dépendance d'implémentation avec US-010

La garde `QUIZ_IN_USE` de l'US-008 (CA-31) — qui empêche la suppression d'un quiz référencé par une partie active — doit être **activée** avant l'implémentation de cette US-011, car une partie en cours utilisera désormais des états intermédiaires (`QUESTION_TITLE`, `QUESTION_OPEN`, `QUESTION_CLOSED`) qui constituent également une partie "active".
