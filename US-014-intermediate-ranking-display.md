# US-014 — Affichage du classement intermédiaire à la demande

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
> **je veux** afficher le classement à tout moment de la partie (même au milieu d'une question),
> **afin de** montrer la progression aux participants et créer de la dynamique dans l'animation.

---

## ✅ Critères d'acceptance

> 🧪 **Exigence de couverture** — Chaque critère d'acceptance listé ci-dessous doit être couvert par **au moins un test automatisé** (unitaire et/ou d'intégration). Un CA non couvert par un test est considéré comme **non livré**. La couverture globale du code de l'US doit être **≥ 90%**, mesurée via `jest --coverage`.

### Déclenchement du classement — `trigger_intermediate_ranking`

| # | Critère | Résultat attendu |
|---|---|---|
| CA-1 | Le maître du jeu envoie `trigger_intermediate_ranking` depuis Angular en état `OPEN` (entre deux questions) | Le serveur calcule le classement intermédiaire basé sur les scores cumulés à ce jour (question précédente terminée), diffuse `intermediate_ranking` à tous les buzzers et à Angular |
| CA-2 | Le maître du jeu envoie `trigger_intermediate_ranking` en état `QUESTION_TITLE`, `QUESTION_OPEN`, `QUESTION_BUZZED`, ou `QUESTION_CLOSED` | Le serveur interrompt momentanément le workflow, diffuse le classement intermédiaire, puis reprend le workflow sans changement d'état |
| CA-3 | Le message `intermediate_ranking` contient le classement complet (rang, nom, score cumulé, temps total) | Données cohérentes avec les scores persistés en base et les calculs en mémoire |
| CA-4 | `trigger_intermediate_ranking` reçu alors que la partie est en état `PENDING`, `COMPLETED`, ou `IN_ERROR` | Serveur envoie `error` à Angular avec code `INVALID_STATE` |
| CA-5 | `trigger_intermediate_ranking` reçu alors qu'aucune question n'a encore été jouée (aucune persistance en base) | Le serveur envoie un classement vide ou avec scores initialisés à 0 pour tous les participants |

### Calcul du classement intermédiaire

| # | Critère | Résultat attendu |
|---|---|---|
| CA-6 | Le classement est trié d'abord par **score cumulé** (décroissant), puis par **temps total cumulé** (croissant) | Résultat conforme aux règles de départage définies dans VISION.md |
| CA-7 | Le classement inclut **tous les participants** de la partie, même ceux avec un score nul | Complétude garantie |
| CA-8 | Les scores cumulés sont calculés à partir des données persistées en base (`T_GAME_ANSWER_GAA`) plus l'état en mémoire si une question est en cours | Cohérence entre persistance et état mémoire |
| CA-9 | Le temps total cumulé inclut la somme de tous les `GAA_TIME_MS` pour chaque participant jusqu'à la dernière question terminée | Calcul conforme à la définition dans VISION.md |

### Affichage sur Angular et les buzzers

| # | Critère | Résultat attendu |
|---|---|---|
| CA-10 | Le message `intermediate_ranking` est diffusé à **tous les buzzers** (non filtré) | Tous les buzzers reçoivent le classement simultanément |
| CA-11 | Le message `intermediate_ranking` est également envoyé à **Angular** | Le maître du jeu voit le classement qu'il vient de déclencher |
| CA-12 | Le contenu du message est identique pour les buzzers et Angular | Uniformité de l'information |
| CA-13 | La diffusion du classement **n'interrompt pas le workflow** (pas de transition d'état) | Si une question MCQ ou SPEED est en cours, celle-ci continue normalement après l'envoi |

### Persistance et reprise

| # | Critère | Résultat attendu |
|---|---|---|
| CA-14 | Le classement intermédiaire est **calculé à la volée**, non persisté en base | Aucune table dédiée requise |
| CA-15 | En cas de crash serveur, le classement est recalculé automatiquement à partir des données persistées en base lors de la reprise | Cohérence garantie |

### Sécurité et transversalité

| # | Critère | Résultat attendu |
|---|---|---|
| CA-16 | Seul le client authentifié avec le rôle `admin` peut envoyer `trigger_intermediate_ranking` | Buzzer envoyant ce message → ignoré silencieusement, log `WARN` |
| CA-17 | Tout message reçu d'un client non authentifié est ignoré | Ignoré silencieusement, log `WARN` |
| CA-18 | Tout message avec un `type` inconnu est ignoré | Ignoré silencieusement, log `WARN` |
| CA-19 | Tout message avec un JSON invalide est ignoré | Ignoré silencieusement, log `WARN` |
| CA-20 | Tests unitaires et d'intégration | Couverture de tests ≥ 90% |

---

## 🔧 Spécifications techniques

| Élément | Choix |
|---|---|
| Runtime | Node.js 24 LTS (dernière version stable disponible) |
| Langage | JavaScript (ES Modules) |
| Base de données | SQLite |
| Tests | Jest (dernière version stable disponible) |
| Principes d'architecture | YAGNI, KISS, DRY, SOLID |

> ⚠️ **Exigence fondamentale** — Toute implémentation de cette US doit scrupuleusement respecter les principes **KISS** (solutions simples), **DRY** (pas de duplication), **YAGNI** (pas de fonctionnalité prématurée) et **SOLID** (architecture modulaire et responsabilités séparées). Ces principes prévalent sur toute optimisation prématurée ou généralisation non justifiée par un besoin immédiat documenté.

### Format des messages WebSocket

**Pilotage — Angular → Serveur**

```json
{ "type": "trigger_intermediate_ranking" }
```

**Diffusion — Serveur → Buzzers + Angular**

```json
{
  "type": "intermediate_ranking",
  "ranking": [
    {
      "rank": 1,
      "participant_name": "Alice",
      "cumulative_score": 45,
      "total_time_ms": 8300
    },
    {
      "rank": 2,
      "participant_name": "Charlie",
      "cumulative_score": 30,
      "total_time_ms": 45000
    },
    {
      "rank": 3,
      "participant_name": "Bob",
      "cumulative_score": 25,
      "total_time_ms": 12400
    }
  ]
}
```

**Erreurs — Serveur → Client émetteur**

```json
{
  "type": "error",
  "code": "INVALID_STATE",
  "message": "Intermediate ranking cannot be displayed in the current game state."
}
```

### Catalogue des codes d'erreur WebSocket

| Code | Contexte |
|---|---|
| `INVALID_STATE` | `trigger_intermediate_ranking` reçu dans un état non autorisé (PENDING, COMPLETED, IN_ERROR) |

### Structure des fichiers

```
src/
  game/
    gameRankingCalculator.js      ← calcul du classement intermédiaire
  game/__tests__/
    gameRankingCalculator.test.js ← tests du calcul
```

### Fonction de calcul du classement

```javascript
/**
 * Calcule le classement intermédiaire basé sur les scores persistés en base
 * et l'état en mémoire si une question est en cours.
 *
 * @param {string} gameId - ID de la partie
 * @returns {Promise<Array>} Classement trié par score (desc) puis temps (asc)
 */
async function calculateIntermediateRanking(gameId) {
  // 1. Requête SQL : agrégation des scores par participant depuis T_GAME_ANSWER_GAA
  // 2. Jointure avec T_GAME_PARTICIPANT_GPT pour inclure les participants sans réponse
  // 3. Tri par score cumulé (DESC) puis temps cumulé (ASC)
  // 4. Ajout du rang (1, 2, 3...)
  // 5. Retour du tableau
}
```

---

## 📝 Logging structuré

**Classement intermédiaire déclenché :**

```json
{
  "timestamp": "2026-03-17T14:35:00.000Z",
  "level": "INFO",
  "event": "GAME_INTERMEDIATE_RANKING_REQUESTED",
  "game_id": "018e4f5d-0000-7000-8000-000000000001",
  "game_status": "QUESTION_OPEN",
  "ranking_size": 3
}
```

---

## 📐 Périmètre

| Inclus | Exclu |
|---|---|
| Déclenchement du classement par le maître du jeu depuis Angular | Sauvegarde du classement en base de données |
| Diffusion du classement simultanée à tous les buzzers et à Angular | Interface Angular d'affichage du classement |
| Calcul du classement basé sur les règles de scoring et de départage | Affichage sur les écrans des buzzers (firmware ESP32-S3) |
| Gestion du classement quelle que soit l'étape de la question (entre questions ou en cours de question) | Historique des classements intermédiaires |
| Tests unitaires et d'intégration (couverture ≥ 90%) | Déploiement / CI-CD |

---

## 🔍 Points de vigilance

### Cohérence du classement pendant une question en cours

Lorsqu'une question est en cours (état `QUESTION_TITLE`, `QUESTION_OPEN`, `QUESTION_BUZZED`, ou `QUESTION_CLOSED`), le classement intermédiaire refléte les scores de la **dernière question complètement terminée**. Les réponses collectées pendant la question en cours ne sont pas prises en compte jusqu'à la persistance (fin de question).

### Calcul et performance

Le calcul du classement implique une agrégation SQL sur toutes les réponses persistées (`T_GAME_ANSWER_GAA`). Pour un quiz avec 20 questions et 10 participants (200 lignes), cette requête est très rapide. Aucun index supplémentaire n'est requis au-delà de ceux définis dans les US précédentes.

### Workflow non modifié

L'affichage du classement intermédiaire n'affecte pas la machine à états. Aucun état supplémentaire n'est créé. Le message est envoyé comme une **notification de diffusion**, sans transition d'état.

### Réutilisation du registre de connexions (US-009)

Le registre `Map<sub, { ws, role, username, connectedAt }>` est utilisé pour :
- Vérifier que seul un client authentifié avec le rôle `admin` peut déclencher le classement
- Diffuser le message à tous les buzzers connectés (itération sur le Map)

Aucune logique de registre n'est dupliquée dans cette US (DRY).

### Pas de modification de la machine à états

Cette US **n'ajoute aucun état** à la machine à états. La transition d'état n'est pas modifiée. Le classement est un **événement de diffusion non-bloquant** qui coexiste avec l'état courant.

---

## 📅 Historique des révisions

| Version | Date | Description |
|---|---|---|
| 1.0 | 2026-03-26 | Version initiale — complète la feature mentionnée dans VISION.md |

