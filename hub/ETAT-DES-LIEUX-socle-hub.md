# État des lieux — Traçabilité du socle hub (US-001 → US-009)

> **Méthode : audit par implémentation réelle, pas par étiquette de test.**
> Chaque CA a été confronté à trois sources : la **spec** (`quiz-buzzer-docs/hub`),
> le **code de production** (`quiz-live-server/src`), et le **corps des tests**.
> Un CA n'est déclaré solide que si le comportement attendu est réellement
> exercé par une assertion qui mord — la seule présence d'un test étiqueté
> `US-00X/CA-Y` ne suffit pas.
>
> **Le réel fait foi.** Ce document est daté ; il reflète l'état du dépôt au
> moment de l'audit (HEAD hub `5407e38`). Toute évolution du code prime sur ce
> récap : re-confronter avant de s'y fier.

---

## 0. Portée et faits de départ

- **HEAD hub audité** : `5407e38` — `test(ws): reject an upgrade request on a path other than /ws`
- **Tests au vert** : 184/184 (24 fichiers), `tsc --noEmit` propre.
- **US auditées** : US-001, US-002, US-003, US-004, US-009 (les seules « prétendument faites »).
- **US absentes du code ET du git log** : **US-005, US-006, US-007, US-008**
  (questions CRUD/filtrage/patch, quiz CRUD) — ~148 CA jamais implémentés.
  Le git log hub saute d'US-004 à US-009. Ce ne sont pas des défauts de
  couverture : c'est du travail **jamais fait**, à *faire*, pas à *auditer*.

> ⚠️ **Conséquence de dépendance** : US-010 (créer une partie) référence un
> `quiz_id` qui doit exister en base. Sans US-005 (questions) ni US-008 (quiz),
> **aucune partie n'est jouable**. La chaîne réelle vers une partie jouable est :
> **US-005 → US-008 → US-010 → US-011**.

---

## 1. Matrice-bilan du socle

| US | CA total | Solides | Partiels / non vérifiés | Trous réels | Faux verts |
|----|:---:|:---:|:---:|:---:|:---:|
| US-001 — server startup | 6  | 4   | CA-5, CA-6 (env `PORT`)              | —                          | —      |
| US-002 — seed users     | 5  | 2   | CA-1 (noms), CA-2 (env + bcrypt)    | —                          | —      |
| US-003 — auth token     | 18 | ~9  | CA-3, 4, 11, 12, 13, 14, 15         | **CA-16 (405)**, **CA-17 (500)** | — |
| US-004 — themes CRUD    | 40 | ~31 | CA-12 / 12a / 19 / 34               | **CA-35 (405)**            | **CA-30** |
| US-009 — websocket      | 29 | ~25 | CA-12, 22, 26                       | —                          | —      |
| **Total** | **98** | **~71** | **~18** | **4** | **1** |

Légende : *Solide* = comportement implémenté + vérifié par un test qui mord ·
*Partiel* = implémenté mais vérification faible ou absente · *Trou réel* =
comportement attendu absent du code · *Faux vert* = test au vert mais
comportement cassé en production réelle.

---

## 2. Détail par US

### US-001 — Démarrage du serveur (6 CA)

- **Solides (4)** : CA-1 (démarre + `/health` 200), CA-2 (heure `HH:mm:ss`),
  CA-3 (1ʳᵉ IPv4 non-loopback + port), CA-4 (fallback si aucune IPv4).
  Tests qui mordent : clock figé, réseau mocké vide, messages exacts assertés.
- **Partiels** :
  - **CA-5** (port via `PORT`, défaut 3000) : mécanisme présent
    (`ProcessEnvironment.port` + `dotenv`), mais **aucun test ne prouve** le
    défaut 3000 ni la variabilité de `PORT`. Le test injecte `port:3000` en dur.
  - **CA-6** : couverture exige « démarrage / pas d'IP / **port personnalisé** » ;
    le cas port personnalisé manque (2 sur 3).
- **Note d'architecture** : `index.ts` non testé = **légitime** (composition pure,
  équivalent Node du `main.cpp` firmware). La preuve de CA-5 incombe donc à
  `ProcessEnvironment` (non audité).

### US-002 — Seed des utilisateurs (5 CA)

- **Solides (2)** : CA-3 (idempotence : `count≠0` → aucun insert),
  CA-4 (politique OWASP : refuse et throw `"Invalid password"`).
- **Partiels** :
  - **CA-1** (11 comptes `quiz_buzzer_01..10` + admin) : le code génère bien les
    noms (`padStart(2,'0')`), mais le test ne vérifie **que le compte (11
    insertions)** — jamais les **noms** ni la répartition des rôles.
  - **CA-2** (mots de passe lus depuis l'environnement, hashés bcrypt) : le test
    passe un `mockEnvironment` en dur → prouve l'usage, **pas la lecture d'env** ;
    le hasher est mocké → **bcrypt réel non prouvé** ici.
- **Robustesse hors-CA** : contrainte SQL `USR_LOGIN ... UNIQUE` = ceinture-bretelles
  sur l'idempotence.

### US-003 — Token d'authentification (18 CA)

- **Solides (~9)** : CA-1 (login → token), CA-2 (HS256), CA-5 (endpoint non
  protégé), CA-6 (`additionalProperties:false`), CA-7 (415), CA-8 (401
  générique), CA-9 (username requis), CA-10 (password requis).
- **Partiels / non vérifiés** :
  - **CA-3** : claims présents, mais `role` mis à la valeur **enum numérique**
    (`0`/`1`) et non `"admin"`/`"buzzer"` comme la spec l'exige ; le test ne
    vérifie que la *présence* du claim. → voir **Dette E**.
  - **CA-4** : durée injectée ; défaut 1h + `JWT_EXPIRATION` non prouvés.
  - **CA-11** : teste body *absent*, pas JSON *malformé*.
  - **CA-12** : 400 oui, mais code `UNKNOWN_FIELDS` non asserté.
  - **CA-13** : 429 oui ; header `Retry-After:60` et « par IP » non prouvés.
  - **CA-14 / CA-15** : `log.info`/`log.warn` présents, **aucun test** ne les capture.
- **Trous réels** :
  - **CA-16 (405 + `Allow: POST`)** : absent (ni code ni test).
  - **CA-17 (500 sans détail)** : aucun `try/catch` dans `token-route`.
- **Excellent hors-CA** : sous-système d'admission WebSocket (`AdmissionPolicy`,
  `JwtValidator.inspectToken` distinguant expired/invalid, resolver, extractors)
  finement testé — prépare solidement US-009.

### US-004 — CRUD des thèmes (40 CA)

- **Solides (~31)** : création/lecture/liste/pagination/update/delete, validation
  regex, normalisation trim+collapse, unicité `COLLATE NOCASE`, tri desc, bornes
  de pagination, `ID_MISMATCH`, `UNKNOWN_FIELDS`, 415, 401 (CA-32), **403 rôle
  (CA-33 — vérifié dans `authentication-middleware.test.ts`)**, 500 (CA-36).
- **Partiels / non vérifiés** : CA-12 / 12a (body & content-type ignorés sur GET,
  reposent sur le défaut Fastify, non figés par test), CA-19 (état vide via la
  route non testé — code correct : `ceil(0/limit)=0`), CA-34 (429 oui, header
  `Retry-After` non asserté).
- **Trou réel** :
  - **CA-35 (405 + header `Allow`)** : absent.
- **Faux vert** :
  - **CA-30 (delete d'un thème avec questions → 409)** : le service throw bien
    `ThemeHasQuestionsError`, **mais** `SqliteThemeRepository.isUsedInQuestions()`
    fait `return false;` (`// TODO: quand QuestionRepository sera disponible`).
    Le test **mocke** ce retour à `true`. En production réelle, un thème lié à
    des questions **serait supprimé quand même**. Vert en test, cassé en réel.
    Cohérent avec l'ordre de dev (les questions n'existent pas encore), mais le
    CA ne peut être déclaré « fait ». → **Dette A**.

### US-009 — Connexion WebSocket (29 CA)

- **La plus complète et la mieux testée du hub.** ~25/29 solides, avec des tests
  multi-clients qui mordent réellement (remplacement de session, éviction admin,
  sync, comptage buzzers/admin).
- **Solides (~25)** : CA-1→11 (attache, `/ws`, refus autre chemin, machine d'auth,
  close codes 4001/4002/4003), CA-13 (4004 session replaced), CA-14 (libération
  de slot), CA-15→17 (admin même format, slot unique, 4004), CA-18→21 (logs
  connected/authenticated/failed/disconnected avec récap), CA-23 (msg post-auth
  ignoré), CA-24 (1011 + `internalError`, y compris sur rejet du resolver),
  CA-27 (`buzzer_connected` à l'admin), CA-28 (`buzzer_disconnected`),
  CA-29 (`request_game_state` → `game_state_sync` + `connected_buzzers`).
- **Partiels / nuances** :
  - **CA-12** (max 10 buzzers) : le registry **mélange buzzers et admin** dans une
    même Map, et le plafond teste `registry.size >= maxConnections`. Donc
    `maxConnections:10` (valeur de `index.ts`) autorise **9 buzzers + 1 admin**,
    pas 10 buzzers + admin. Le test force `maxConnections=1` et n'exerce jamais
    la combinaison admin + 10 buzzers → la divergence reste invisible.
    → **Dette B**.
  - **CA-22** : « message d'un non-authentifié ignoré » — le design consomme le
    **premier** message comme tentative d'auth (pas d'état « connecté mais
    silencieux »). Interprétation, pas bug. Volet timeout (4003) bien testé.
  - **CA-26** : rate limiting appliqué **dans** le handler `/ws`, donc **après**
    l'upgrade, alors que la spec dit « détruite sans upgrade ». Résultat visible
    correct et testé (close 4006), mais *timing* divergent. → **Dette « Window 2 »**.
- **Note close codes** : 4005 = "Server is full." (CA-12), 4006 = "Rate limit
  exceeded." (CA-26). Les deux ont désormais un CA parent — l'ancienne remarque
  « 4005 sans CA parent » est **résorbée** (le réel est en avance sur le récap).

---

## 3. Dettes de complétude, ordonnées

**Motif transversal** : le cœur fonctionnel (auth, JWT, CRUD, WebSocket temps réel)
est solide et bien testé. Les faiblesses se concentrent sur les **exigences
normatives transversales** (405, 500, headers, logs, lecture d'environnement,
valeurs sémantiques).

| # | Dette | Gravité | Déclencheur de résorption |
|---|-------|---------|---------------------------|
| **A** | **Faux vert CA-30 / US-004** — `isUsedInQuestions()` renvoie `false` en dur ; un thème lié à des questions serait supprimé en prod. | 🔴 Corruption de données possible | Dès qu'US-005 (questions) existe. |
| **B** | **CA-12 / US-009** — le plafond mélange admin + buzzers ; en réel 9 buzzers au lieu de 10. | 🟠 Comportemental | Avant le premier jeu à 10 buzzers physiques. |
| **C** | **405 Method Not Allowed absent partout** (CA-16/US-003, CA-35/US-004). | 🟡 Conformité, effort faible | Passe de mise en conformité REST. |
| **D** | **Gestion 500 fragile** (CA-17/US-003 sans `try/catch`) — risque d'exposer un détail technique. | 🟡 Sécurité des erreurs | Passe de mise en conformité REST. |
| **E** | **`role` string vs enum dans le JWT REST** (CA-3/US-003) — `/token` porte `role:1`, pas `"buzzer"`. NB : côté WebSocket, `auth_success` utilise bien `toRoleLabel`. Incohérence entre les deux canaux. | 🟡 Interop consommateurs | Avant qu'un client décode le rôle du JWT REST. |
| **F** | **Lecture d'environnement non testée de bout en bout** (CA-5/US-001, CA-2/US-002, CA-4/US-003, CA-13). Tout est renvoyé à `ProcessEnvironment`, non audité. | 🟢 Vérification | Un dump `process-environment.*` ferme trois US d'un coup. |
| **G** | **Logs et headers non assertés** (CA-14/15/US-003 ; `Retry-After` CA-13/US-003, CA-34/US-004). Code souvent présent, vérification absente. | 🟢 Vérification | Resserrage de tests. |
| **H** | **Vérifications faibles** (noms de comptes CA-1/US-002 ; JSON malformé CA-11/US-003 ; état vide CA-19/US-004). | 🟢 Vérification | Resserrage de tests. |

---

## 4. Ce que ça signifie pour la suite

Le socle hub est **substantiel mais pas « fini »** au sens strict des specs :
~71/98 CA solides, avec un angle mort net sur les exigences transversales
normatives. **Aucun de ces trous n'empêche d'avancer vers le jeu** — à condition
de les connaître pour ne pas s'appuyer dessus (notamment les dettes A et B).

Deux caps possibles pour la suite, à trancher :

1. **Consolider le socle** — résorber les dettes A→H (surtout A, B, C, D) pour un
   hub conforme avant d'ajouter des fonctionnalités. Petites sessions TDD ciblées,
   très « un commit par session ».
2. **Avancer vers le jeu** — attaquer US-005 (questions) → US-008 → US-010 → US-011,
   en actant les dettes du socle comme connues et datées. C'est le chemin qui
   « réveille la dalle » plus vite (le firmware attend un hub capable d'émettre
   les messages de déroulé de partie).

Les dettes A et B méritent d'être **notées formellement** mais peuvent attendre
leur déclencheur naturel. Les dettes C et D sont rapides et rendraient le socle
propre. Rien n'est bloquant : si le plaisir est le moteur, **US-005 → jeu** reste
le cap qui sort de « Connecté » affiché à l'écran.

---

*Audit réalisé par confrontation spec ↔ code ↔ tests, US par US. Document daté à
re-confronter au réel avant toute décision : le git log et les tests priment sur
ce récap.*
