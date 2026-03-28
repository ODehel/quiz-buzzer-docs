# US-018 — Déclenchement des sons système préchargés sur les buzzers

## 📋 Contexte projet

Voir [VISION.md](VISION.md) pour la description complète du projet et de ses quatre applications.

---

## 🎯 User Story

> **En tant que** maître du jeu,
> **je veux** que les buzzers jouent automatiquement les sons appropriés aux événements de jeu, et que je puisse également en déclencher manuellement depuis Angular,
> **afin de** rendre la partie plus immersive sans configuration supplémentaire.

---

## ✅ Critères d'acceptance

> 🧪 **Exigence de couverture** — Voir [Conventions techniques — Couverture des tests](CONVENTIONS-TECHNIQUES.md#-exigence-de-couverture-des-tests). Chaque CA doit être couvert par au moins un test automatisé. Couverture globale ≥ 90 %.

### Catalogue des sons système

| Identifiant | Événement déclencheur | Déclenchement | Cible |
|---|---|---|---|
| `BUZZ_PRESSED` | Un buzzer appuie sur le bouton buzz (SPEED) | Automatique — serveur | Buzzer buzzeur uniquement |
| `BUZZ_LOCKED` | Un autre joueur a buzzé en premier | Automatique — serveur | Tous les buzzers non buzzeurs |
| `BUZZ_INVALIDATED` | La réponse orale du buzzeur est invalidée | Automatique — serveur | Buzzer invalidé uniquement |
| `CORRECT_ANSWER` | Réponse correcte validée (MCQ ou SPEED) | Automatique — serveur | Buzzer concerné uniquement |
| `WRONG_ANSWER` | Réponse incorrecte (MCQ) ou invalidée définitivement (SPEED) | Automatique — serveur | Buzzer concerné uniquement |
| `TIMER_END` | Expiration du chrono sans bonne réponse | Automatique — serveur | Tous les buzzers connectés |
| `GAME_START` | La partie passe en état `OPEN` | Automatique — serveur | Tous les buzzers connectés |
| `GAME_END` | La partie passe en état `COMPLETED` | Automatique — serveur | Tous les buzzers connectés |
| `WAITING` | En attente du déclenchement de la prochaine question (état `OPEN` entre deux questions) | Manuel — Angular | Tous les buzzers connectés |
| `SUSPENSE` | Générique — ambiance pendant l'affichage du titre de question | Manuel — Angular | Tous les buzzers connectés |

### Déclenchements automatiques — Serveur

| # | Critère | Résultat attendu |
|---|---|---|
| CA-1 | Lors de l'envoi de `buzz_accepted` à un buzzer (US-012) | Le serveur envoie simultanément `play_system_sound { sound_id: "BUZZ_PRESSED" }` au même buzzer |
| CA-2 | Lors de l'envoi de `buzz_locked` aux autres buzzers (US-012) | Le serveur envoie simultanément `play_system_sound { sound_id: "BUZZ_LOCKED" }` aux mêmes cibles |
| CA-3 | Lors de l'envoi de `buzz_invalidated` au buzzer invalidé (US-012) | Le serveur envoie simultanément `play_system_sound { sound_id: "BUZZ_INVALIDATED" }` au même buzzer |
| CA-4 | Lors de l'envoi du `question_result` à un buzzer avec `correct: true` (US-011 et US-012) | Le serveur envoie simultanément `play_system_sound { sound_id: "CORRECT_ANSWER" }` au même buzzer |
| CA-5 | Lors de l'envoi du `question_result` à un buzzer avec `correct: false` (US-011 et US-012) | Le serveur envoie simultanément `play_system_sound { sound_id: "WRONG_ANSWER" }` au même buzzer |
| CA-6 | Lors de l'envoi de `timer_end` (US-011 et US-012) | Le serveur envoie simultanément `play_system_sound { sound_id: "TIMER_END" }` à tous les buzzers connectés |
| CA-7 | Lors de la transition de la partie vers l'état `OPEN` (démarrage de partie, US-010) | Le serveur envoie `play_system_sound { sound_id: "GAME_START" }` à tous les buzzers connectés |
| CA-8 | Lors de la transition de la partie vers l'état `COMPLETED` (US-011 et US-012) | Le serveur envoie `play_system_sound { sound_id: "GAME_END" }` à tous les buzzers connectés |
| CA-9 | Si aucun buzzer n'est connecté au moment d'un déclenchement automatique | Le serveur traite l'envoi sans erreur, log `INFO SYSTEM_SOUND_NO_TARGETS` |

### Déclenchements manuels — Angular

| # | Critère | Résultat attendu |
|---|---|---|
| CA-10 | Angular envoie `trigger_system_sound` avec un `sound_id` valide et `targets` absent ou vide | Broadcast à tous les buzzers connectés |
| CA-11 | Angular envoie `trigger_system_sound` avec un `sound_id` valide et une liste `targets` non vide | Envoi uniquement aux buzzers ciblés connectés |
| CA-12 | `sound_id` absent ou vide dans le message `trigger_system_sound` | Serveur envoie `error` à Angular avec code `INVALID_MESSAGE` |
| CA-13 | `sound_id` ne correspond pas à un identifiant du catalogue | Serveur envoie `error` à Angular avec code `UNKNOWN_SYSTEM_SOUND` |
| CA-14 | Un `username` dans `targets` ne correspond à aucun buzzer connecté | Ignoré silencieusement — log `WARN SYSTEM_SOUND_TARGET_NOT_CONNECTED` |
| CA-15 | `trigger_system_sound` envoyé par un client avec le rôle `buzzer` | Ignoré silencieusement — log `WARN` |
| CA-16 | `trigger_system_sound` envoyé par un client non authentifié | Ignoré silencieusement — log `WARN` |

### Réception côté buzzer

| # | Critère | Résultat attendu |
|---|---|---|
| CA-17 | Le buzzer reçoit `play_system_sound` avec un `sound_id` connu | Le buzzer joue le son préchargé correspondant |
| CA-18 | Deux messages `play_system_sound` arrivent quasi-simultanément sur un buzzer | Le buzzer joue les sons séquentiellement (file d'attente côté firmware) — hors périmètre serveur, documenté comme contrainte firmware |

### Sécurité et transversalité

| # | Critère | Résultat attendu |
|---|---|---|
| CA-19 | Tout message `trigger_system_sound` reçu d'un client non authentifié | Ignoré silencieusement — log `WARN` |
| CA-20 | Erreur serveur inattendue lors du traitement | Log `INTERNAL_ERROR` niveau `ERROR`, connexion fermée avec code `1011` si applicable |
| CA-21 | Tests unitaires et d'intégration | Couverture de tests ≥ 90% |

---

## 🔄 Diagramme de flux

![Diagramme de flux — US-018 — Déclenchement des sons système préchargés](diagrams/US-018-system-sounds-trigger.png)

---

## 🔀 Diagramme de séquences

![Diagramme de séquences — US-018 — Déclenchement des sons système préchargés](diagrams/US-018-system-sounds-trigger-sequence.png)

---

## 🔧 Spécifications techniques

Voir les [Conventions techniques](CONVENTIONS-TECHNIQUES.md) pour la stack complète, les principes d'architecture (KISS, DRY, YAGNI, SOLID) et les conventions de données.

### Pas de modification de schéma SQL

Cette US n'introduit aucune table ni colonne. Le catalogue des sons système est défini **en dur dans le code** sous forme de constante partagée — il ne nécessite pas de persistance en base.

```javascript
// src/constants/systemSounds.js
export const SYSTEM_SOUNDS = new Set([
  'BUZZ_PRESSED',
  'BUZZ_LOCKED',
  'BUZZ_INVALIDATED',
  'CORRECT_ANSWER',
  'WRONG_ANSWER',
  'TIMER_END',
  'GAME_START',
  'GAME_END',
  'WAITING',
  'SUSPENSE',
]);
```

### Format des messages WebSocket

**Déclenchement manuel — Angular → Serveur**

```json
{
  "type": "trigger_system_sound",
  "sound_id": "WAITING",
  "targets": ["quiz_buzzer_01", "quiz_buzzer_03"]
}
```

> `targets` est optionnel. Absent ou tableau vide → broadcast à tous les buzzers connectés.

**Diffusion — Serveur → Buzzer(s)**

Déclenchement automatique ou manuel, le message envoyé au buzzer est identique :

```json
{
  "type": "play_system_sound",
  "sound_id": "BUZZ_PRESSED"
}
```

**Erreur — Serveur → Angular**

```json
{
  "type": "error",
  "code": "UNKNOWN_SYSTEM_SOUND",
  "message": "Unknown system sound identifier."
}
```

```json
{
  "type": "error",
  "code": "INVALID_MESSAGE",
  "message": "Missing or invalid field: sound_id."
}
```

### Intégration dans les workflows existants (US-010, US-011, US-012)

Les déclenchements automatiques sont intégrés **en ligne** dans les handlers existants, immédiatement après l'envoi du message métier correspondant. L'envoi du son système est **non bloquant** : un échec d'envoi (buzzer déconnecté entre-temps) est géré silencieusement via un try/catch local et un log `WARN`.

```javascript
// Exemple conceptuel — dans gameSpeedProcessor.js
sendToClient(buzzerWs, { type: 'buzz_accepted' });
sendSystemSound(buzzerWs, 'BUZZ_PRESSED');         // non bloquant
```

La fonction utilitaire `sendSystemSound(ws, soundId)` est définie dans `src/utils/soundUtils.js` et réutilisée dans tous les workflows concernés (DRY).

### Catalogue des codes d'erreur WebSocket

| Code | Contexte |
|---|---|
| `UNKNOWN_SYSTEM_SOUND` | `sound_id` absent du catalogue `SYSTEM_SOUNDS` |
| `INVALID_MESSAGE` | Champ `sound_id` absent ou de type incorrect dans `trigger_system_sound` |

---

## 📝 Logging structuré

| Événement | Niveau | Champs notables |
|---|---|---|
| `SYSTEM_SOUND_SENT` | `INFO` | `sound_id`, `trigger` (`auto` ou `manual`), `targets_reached` |
| `SYSTEM_SOUND_NO_TARGETS` | `INFO` | `sound_id`, `trigger` — aucun buzzer connecté |
| `SYSTEM_SOUND_TARGET_NOT_CONNECTED` | `WARN` | `sound_id`, `username` — buzzer ciblé manuellement mais non connecté |
| `SYSTEM_SOUND_SEND_FAILED` | `WARN` | `sound_id`, `username`, `error` — échec d'envoi sur un buzzer (déconnexion entre-temps) |

---

## 📐 Périmètre

| Inclus | Exclu |
|---|---|
| Catalogue des 10 sons système défini et versionné dans le code | Gestion des fichiers audio sur le serveur (US-016, US-017) |
| Déclenchements automatiques intégrés dans US-010, US-011, US-012 | Firmware ESP32-S3 (file d'attente, lecture audio) |
| Déclenchement manuel `trigger_system_sound` depuis Angular | Interface Angular |
| Ciblage par username ou broadcast | Ajout/suppression dynamique de sons via REST (YAGNI) |
| Fonction utilitaire `sendSystemSound` partagée (DRY) | Déploiement / CI-CD |
| Logging structuré des envois | |
| Tests unitaires et d'intégration (couverture ≥ 90%) | |

---

## 🔍 Points de vigilance

### Catalogue défini en code, pas en base

Le catalogue des sons système est immuable dans le cadre du projet et ne nécessite pas d'interface de gestion. Le définir comme constante `Set` en code est plus simple (KISS), permet une validation synchrone sans requête SQL, et facilite le partage entre modules (DRY). Toute évolution du catalogue se fait via une modification du code versionnée.

### Envoi non bloquant obligatoire

Les déclenchements automatiques s'exécutent dans le flux critique des workflows MCQ et SPEED. Un échec d'envoi (buzzer déconnecté dans la même milliseconde) ne doit **jamais** interrompre le workflow. Chaque appel à `sendSystemSound` est isolé dans un try/catch local — les erreurs sont loggées au niveau `WARN` sans propagation.

### Simultanéité avec le message métier

Le son système et le message métier correspondant sont envoyés dans la même boucle d'événements Node.js, séquentiellement sur la même connexion WebSocket. L'ordre garanti est : **message métier d'abord, son système ensuite**. Cela permet au firmware ESP32 de mettre à jour son affichage avant de déclencher l'audio.

### Réutilisation du registre de connexions (DRY)

La résolution des connexions actives (broadcast ou ciblage) s'appuie sur le registre en mémoire défini en US-009, itéré de la même façon que dans US-017. La fonction `sendSystemSound` accepte soit une instance `WebSocket` directe (cas automatique), soit un `username` ou `null` pour broadcast (cas manuel), sans dupliquer la logique d'itération du registre.

### Dépendances d'implémentation

Cette US **étend** les handlers existants des US-010, US-011 et US-012. Elle doit être implémentée **après** ces trois US. La constante `SYSTEM_SOUNDS` et la fonction `sendSystemSound` sont créées dans cette US et importées rétroactivement dans les modules des US précédentes.
