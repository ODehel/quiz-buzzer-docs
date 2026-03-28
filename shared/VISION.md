# VISION.md — Quiz Buzzer

## 📋 Contexte projet

Le projet **Quiz Buzzer** se décompose en quatre applications :

| Application | Technologie | Rôle |
|---|---|---|
| **Buzzers** | PlatformIO / ESP32-S3 | Périphériques physiques de jeu |
| **App mobile** | Android / NFC | Configuration WiFi des buzzers |
| **App maître de jeu** | Angular | Interface de gestion des parties |
| **Serveur (hub)** | Node.js / JavaScript | Communication WebSocket entre l'app Angular et les buzzers, gestion du workflow des parties |

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

Voir [CONVENTIONS-TECHNIQUES.md](CONVENTIONS-TECHNIQUES.md) pour les détails d'application de ces principes dans le hub Node.js.

---

## 📚 Documents de référence transversaux

| Document | Contenu |
|---|---|
| [CONVENTIONS-TECHNIQUES.md](CONVENTIONS-TECHNIQUES.md) | Stack technique, principes KISS/DRY/YAGNI/SOLID, couverture des tests, conventions de données |
| [AUTHENTIFICATION.md](AUTHENTIFICATION.md) | Mécanisme JWT, payload, architecture middleware |
| [SECURITE-TRANSVERSALE.md](SECURITE-TRANSVERSALE.md) | Critères de sécurité transversaux, cas de tests |
| [error-codes.md](../hub/error-codes.md) | Catalogue centralisé des codes d'erreur |

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
| US-011 | Workflow d'une question MCQ | ✅ Documentée |
| US-012 | Workflow d'une question SPEED | ✅ Documentée |
| US-013 | Consultation des résultats d'une partie | ✅ Documentée |
| US-014 | Affichage du classement intermédiaire à la demande | ✅ Documentée |
| US-015 | Heartbeat WebSocket | ✅ Documentée |
| US-016 | Upload et gestion des fichiers médias des questions | ✅ Documentée |
| US-017 | Gestion des jingles et sons personnalisés | ✅ Documentée |
| US-018 | Déclenchement des sons système préchargés sur les buzzers | ✅ Documentée |
| US-019 | Reprise de partie après crash serveur | ✅ Documentée |
| US-020 | Health check | ✅ Documentée |
| US-021 | Refresh du token JWT (WebSocket) | ✅ Documentée |
| US-022 | Logging et observabilité | ✅ Documentée |

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
| 1.1 | 2026-03-27 | Ajout US-019 à US-022 (reprise crash, health check, refresh JWT, logging) |
