# Méthode de travail par session

Source de vérité de la méthode, commune aux 4 dépôts Buzz'O'Live
(quiz-live-buzzer, quiz-live-server, quiz-live-angular, quiz-buzzer-docs).

## Principe

**Le réel fait foi, pas le handoff.** Le handoff est une hypothèse de continuité :
à chaque ouverture, on la confronte à l'état réel (git, tests, fichiers) et c'est
le réel qui tranche.

## Rôles

- **Claude** fait tout : code, tests, docs, et exécute git (branche, commit, fast-forward
  de `main`, suppression de la branche de session) via le dossier connecté.
  Il ne fait **jamais** `git push` : il n'a pas les identifiants GitHub.
- **Olivier** valide aux deux portes, lance les smoke tests et fait le `git push`.
  Il ne code pas.

## Cycle d'une session

Une session = un commit = une branche `session/<titre-du-commit>`.
Le titre de la session est le titre du commit.

1. **Ouverture (scriptée)**
   - `git status` et `git log -5` sur les dépôts concernés.
   - Arbre non propre ou branche autre que `main` : stop, on le signale.
   - Création de la branche `session/<titre-du-commit>`.
   - Confrontation du handoff précédent à l'état réel.
2. **Porte 1 : cadrage** (≤ 10 lignes), proposé par Claude. Cible de la session et
   choix de conception. Rien n'est écrit avant l'accord d'Olivier.
3. **Réalisation** sur la branche de session.
4. **Vérification** : tests, type-check, lint, mutations, puis smoke tests (voir ci-dessous).
5. **Porte 2 : revue.**
   - `git diff --stat`, résumé par fichier.
   - Sorties des smoke tests.
   - Points à challenger.
   - Section « ce que j'aurais pu faire autrement et pourquoi j'ai tranché ainsi ».
   - STOP : pas de commit avant le « ok » explicite d'Olivier. Les corrections demandées
     sont appliquées, puis le diff est remontré.
6. **Commit** par Claude, après l'accord de porte 2 uniquement, puis fast-forward de
   `main` et suppression de la branche de session.
7. **Push** par Olivier.
8. **Clôture** : voir « Handoff ».

## Smoke tests

Claude n'a pas PowerShell. Il écrit un bloc de commandes, Olivier le lance. La sortie va
dans `C:\Users\olivi\source\repos\QuizBuzzer\smoke-test-summary.txt` ; Claude la lit puis
supprime le fichier.

## Handoff

- Fichiers centralisés dans `quiz-buzzer-docs/docs/sessions/` (modèle : `TEMPLATE.md`).
- Commit de clôture `docs(sessions): <titre>` pour les sessions portant une US.
- Pas de handoff pour les sessions de workflow.

## Règles git

- Commit **seulement après l'accord de porte 2**.
- Staging **fichier par fichier**, jamais `git add .`.
- Pas de force push, pas de commit direct sur `main`.
- Identité : `git -c user.name=... -c user.email=...` avec celle d'Olivier ; le message
  porte les lignes `Co-Authored-By` et `Claude-Session`.
- **Un seul commit par session** (squash si besoin).
- La branche de session est supprimée après le fast-forward de `main`.

## Pièges connus

- `core.autocrlf=true` chez Olivier : `git status` côté Claude voit environ 84 faux
  « modifiés » (CRLF). Restreindre chaque `git diff` à un fichier.
- `.claude/settings.local.json` est ignoré globalement chez Olivier, pas côté Claude :
  il apparaît non suivi, ne jamais l'indexer.
- Un git qui laisse un verrou (`.lock`) : `mv` le fichier plutôt que `rm`, sauf si la
  permission de suppression a été accordée.

## Conventions

- **Types de commit**
  - `feat` : capacité atteignable en production.
  - `fix` : correction d'un comportement incorrect.
  - `chore` : code dormant (pas encore atteignable) ou outillage.
  - `refactor` : comportement inchangé.
  - `docs` : documentation seule.
- **Description** : à l'impératif, décrit la capacité observable, jamais le mécanisme.
- **Test né vert** = spec test : mutation obligatoire avant commit.
- **YAGNI** : on n'écrit que ce que la cible de la session exige.
- **Ordre** : la logique de `lib/` précède l'adaptateur de `src/`.
- **Dette et décisions** : `DEBTS.md` et `DECISIONS.md` sont mis à jour dans le commit
  de session.
