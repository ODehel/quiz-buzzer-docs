![Page de couverture — Vision globale](diagrams/covers/VISION-cover.png)

# Quiz Buzzer — Vision globale du projet

## 📋 Contexte projet

Le projet **Quiz Buzzer** se décompose en quatre applications :

| Application | Technologie | Rôle |
|---|---|---|
| **Buzzers** | PlatformIO / ESP32-S3 | Périphériques physiques de jeu |
| **App mobile** | Android / NFC | Configuration WiFi des buzzers |
| **App maître de jeu** | Angular | Interface de gestion des parties |
| **Serveur (hub)** | Node.js / JavaScript | Communication WebSocket entre l'app Angular et les buzzers, gestion du workflow des parties |

---

## 🎯 Vision du projet

> **Quiz Buzzer** est un dispositif complet pour créer et animer des quiz en présentiel.
> Il repose sur quatre applications communicant sur un réseau **WiFi local**, sans accès internet.
> Le serveur Node.js et l'application Angular tournent sur le **même PC Windows**.
> L'application Angular est **indépendante** du serveur Node.js.

---

## 🕹️ Matériel — Buzzer ESP32-S3

Chaque buzzer est un périphérique physique autonome embarquant :

| Composant | Rôle |
|---|---|
| Écran LCD TFT | Affichage des questions, propositions et classements |
| 4 boutons poussoir A, B, C, D | Réponses aux questions MCQ |
| 1 gros bouton buzzer | Réponse aux questions SPEED |
| Haut-parleurs | Diffusion de sons et jingles |
| Batterie | Alimentation autonome |

Le dispositif supporte **jusqu'à 10 buzzers simultanés** (contrainte financière et organisationnelle).

> ⚠️ **À compléter** — Les états affichés sur l'écran LCD TFT du buzzer restent à préciser pour les situations suivantes : écran d'attente entre deux questions, affichage lors d'un buzze (avant validation du maître du jeu), affichage après bonne réponse, affichage après mauvaise réponse, affichage lors de l'élimination d'un joueur en mode SPEED, affichage en fin de partie.

---

## 🎮 Déroulement d'une partie

### Préparation

Le maître du jeu crée une partie depuis Angular en associant :
- Un **quiz** (ensemble ordonné de questions)
- Des **participants** (noms libres, de 1 à 10)

La partie démarre en statut `PENDING`, puis passe en `OPEN` à l'initiative du maître du jeu.

### Pilotage

C'est le **maître du jeu** qui pilote manuellement chaque étape depuis Angular. Les transitions d'état sont déclenchées par ses interactions. L'application Angular n'est visible que par le maître du jeu.

### Classement intermédiaire

Le maître du jeu peut afficher le classement à **n'importe quel moment** de la partie. Il est affiché simultanément sur Angular et sur les buzzers.

### Fin de partie

Le maître du jeu déclenche la fin de la partie. Le **classement final** est affiché simultanément sur Angular et sur tous les buzzers.

---

## ❓ Types de questions

### Mode MCQ — Questions à choix multiples

| Étape | Déclencheur | Action |
|---|---|---|
| 1 | Maître du jeu | Affichage de l'**intitulé** de la question sur Angular et les buzzers |
| 2 | Maître du jeu | Affichage des **4 propositions** A/B/C/D + démarrage simultané du chronomètre |
| 3 | Joueur | Appui sur **A, B, C ou D** — réponse immédiate, irréversible, buzzer bloqué ensuite |
| 4 | Automatique | Quand tous les joueurs ont répondu **ou** que le temps expire |
| 5 | Maître du jeu | Déclenchement de l'affichage de la **correction** sur les buzzers |

- Tous les joueurs ayant donné la bonne réponse remportent les points de la question.
- Une fois sa réponse envoyée, un joueur ne peut plus interagir jusqu'à la question suivante.
- Si le temps expire sans qu'un joueur ait répondu, son temps de réponse est égal à `time_limit`.

### Mode SPEED — Questions de rapidité

| Étape | Déclencheur | Action |
|---|---|---|
| 1 | Maître du jeu | Affichage de l'**intitulé** + démarrage simultané du chronomètre — buzzers actifs |
| 2 | Joueur | Appui sur le **gros bouton buzzer** — tous les autres buzzers sont bloqués |
| 3 | Joueur | Réponse **orale** |
| 4 | Maître du jeu | **Validation ou invalidation** de la réponse depuis Angular |

**Si la réponse est valide :** le joueur remporte les points de la question.

**Si la réponse est invalide :** le joueur est éliminé de la question, le chronomètre reprend là où il s'était arrêté, les autres joueurs peuvent à nouveau buzzer.

**Si le temps expire sans bonne réponse :** tout le monde est déclaré perdant, aucun point n'est attribué, le temps enregistré est `time_limit` pour tous.

> **Note :** Le maître du jeu ne peut pas passer une question sans attribuer de points.

---

## 🏆 Scoring et classement

### Attribution des points

- Les points attribués sont ceux **définis sur la question** (valeur fixe entre 1 et 50)
- **Aucun bonus de rapidité**
- **Aucune pénalité** pour mauvaise réponse

### Critères de départage (par ordre de priorité)

| Priorité | Critère | Avantage |
|---|---|---|
| 1 | Total de points | Le plus élevé gagne |
| 2 | Temps de réponse cumulé | Le plus court gagne |

### Calcul du temps de réponse

- Le temps de réponse est enregistré **par joueur par question**
- En cas d'expiration du chrono sans réponse, le temps enregistré est égal à `time_limit` de la question
- Les scores et réponses sont sauvegardés en base **à la fin de chaque question complètement terminée**

---

## ⚡ Synchronisation SPEED — Compensation de latence

Pour déterminer qui a buzzé en premier en mode SPEED, deux timestamps sont combinés :

| Source | Description |
|---|---|
| **Timestamp buzzer** | Horodatage local de l'ESP32 au moment de l'appui |
| **Timestamp serveur** | Horodatage de réception du message WebSocket côté serveur |

Une **logique de compensation de latence** est appliquée pour trancher en cas de buzzes quasi-simultanés. Le serveur fait autorité sur le résultat final.

---

## 🔊 Sons et jingles

Deux catégories de sons coexistent :

| Catégorie | Stockage | Déclenchement |
|---|---|---|
| Sons système (buzzer pressé, attente…) | Préchargés sur chaque ESP32 | Signal WebSocket du serveur (identifiant de son) |
| Jingles et sons personnalisés | Stockés sur le serveur Node.js | Envoyés via WebSocket vers un ou plusieurs buzzers ciblés |

- Chaque buzzer possède un **son de buzzer unique** qui lui est propre.
- Le maître du jeu peut diffuser des sons depuis Angular vers **un ou plusieurs buzzers précis**.

> ⚠️ **À compléter** — La liste précise des sons préchargés sur chaque ESP32 reste à définir (sons système : buzzer pressé, bonne réponse, mauvaise réponse, élimination, fin de partie, attente, etc.).

---

## 📡 Communication WebSocket

- Les buzzers reçoivent les **questions et instructions** via WebSocket
- Les buzzers envoient leurs **réponses et événements** (buzze, réponse MCQ) via WebSocket
- L'application Angular communique avec le serveur via WebSocket pour le **pilotage temps réel**

### Reconnexion buzzer

En cas de perte de connexion WiFi en cours de partie :

| Étape | Comportement |
|---|---|
| Tentatives 1 à 3 | Le buzzer tente de se reconnecter automatiquement |
| Après 3 échecs | La connexion est définitivement perdue |
| Conséquence | Le joueur est considéré comme **éliminé de la partie** |

---

## 💾 Persistance et reprise après crash

### Sauvegarde

Les scores et réponses sont sauvegardés en base de données **à la fin de chaque question complètement terminée**.

### Reprise automatique

En cas de crash du serveur en cours de partie :
- La reprise est **automatique** au redémarrage du serveur
- La partie reprend à la **dernière question complètement terminée** dont le résultat a été validé et sauvegardé

### Historique

Un historique des parties jouées et de leurs résultats est conservé en base de données. Il n'est **pas consultable** depuis l'application Angular.

---

## 🔧 Principes de développement

Toute la codebase de **tous les projets** (serveur Node.js, Angular, firmware ESP32-S3, application Android) respecte les principes suivants :

| Principe | Description |
|---|---|
| **KISS** | Solutions simples, pas de sur-ingénierie |
| **DRY** | Pas de duplication de code ou de logique |
| **YAGNI** | Pas de fonctionnalité non justifiée par un besoin immédiat documenté |
| **SOLID** | Architecture modulaire, responsabilités séparées |

> ⚠️ **Exigence fondamentale** — Ces principes prévalent sur toute optimisation prématurée ou généralisation non justifiée par un besoin immédiat documenté. Ils s'appliquent sans exception à l'ensemble des projets.

---

## 🗺️ US documentées

| US | Titre | Statut |
|---|---|---|
| US-001 | Démarrage du serveur | ✅ Documentée |
| US-002 | Seed des comptes utilisateurs | ✅ Documentée |
| US-003 | Authentification et émission du token JWT | ✅ Documentée |
| US-004 | CRUD des thèmes de questions | ✅ Documentée |
| US-005 | CRUD de base des questions | ✅ Documentée |
| US-006 | Filtrage avancé de la liste des questions | ✅ Documentée |
| US-007 | Modification partielle des questions (PATCH) | ✅ Documentée |
| US-008 | CRUD des quiz | ✅ Documentée |
| US-009 | Connexion WebSocket des buzzers et de l'application Angular | ✅ Documentée |
| US-010 | CRUD des parties | ✅ Documentée |

---

## 🔍 Points de vigilance transversaux

### Réseau local uniquement

Le dispositif fonctionne exclusivement sur un réseau WiFi local (LAN). Aucune fonctionnalité ne doit supposer un accès internet.

### Latence et temps réel

La latence réseau WiFi local doit être prise en compte pour toute fonctionnalité de synchronisation, en particulier pour le mode SPEED où la compensation de latence est critique pour désigner le bon vainqueur.

### Indépendance des applications

L'application Angular est indépendante du serveur Node.js. Elles communiquent exclusivement via l'API REST et le WebSocket — aucun couplage direct.

### Contrainte matérielle ESP32-S3

Les buzzers ESP32-S3 sont des périphériques embarqués à ressources limitées. Les messages WebSocket doivent être aussi légers que possible. Les sons trop volumineux doivent être préchargés sur l'appareil plutôt qu'envoyés à la volée.

---

## 📅 Historique des révisions

| Version | Date | Description |
|---|---|---|
| 1.0 | 2026-03-16 | Version initiale |
