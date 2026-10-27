# Méthode de travail par session

Source de vérité de la méthode, commune aux 4 dépôts Buzz'O'Live
(quiz-live-buzzer, quiz-live-server, quiz-live-angular, quiz-buzzer-docs).

## Principe

**Le réel fait foi, pas le handoff.** Le handoff est une hypothèse de continuité :
à chaque ouverture, on la confronte à l'état réel (git, tests, fichiers) et c'est
le réel qui tranche.

## Rôles

- **Claude** fait tout : code, tests, docs, exécution de `git commit` et `git push`.
- **Olivier** valide, aux deux portes. Il ne code pas.

## Cycle d'une session

Une session = un commit. Le titre de la session est le titre du commit.

1. **Ouverture (scriptée)**
   - `git status` et `git log -5`.
   - Arbre non propre ou branche autre que `main` : stop, on le signale.
   - Création de la branche `session/<titre-du-commit>`.
   - Confrontation du handoff précédent à l'état réel.
2. **Porte 1 : cadrage** (≤ 10 lignes). Cible de la session et choix de conception.
   Rien n'est écrit avant l'accord d'Olivier.
3. **Réalisation** sur la branche de session.
4. **Vérification** : tests, type-check, lint, mutations.
5. **Porte 2 : revue du diff.**
   - `git diff --stat`.
   - Résumé par fichier.
   - Points à challenger.
   - Section « ce que j'aurais pu faire autrement et pourquoi j'ai tranché ainsi ».
   - STOP : pas de commit avant le « ok » explicite d'Olivier. Les corrections demandées
     sont appliquées, puis le diff est remontré.
6. **Commit et push** (voir règles git), après l'accord de porte 2 uniquement.
7. **Clôture** avec handoff (`docs/sessions/TEMPLATE.md`).

## Règles git

- Commit et push **seulement après l'accord de porte 2**.
- Staging **fichier par fichier**, jamais `git add .`.
- Pas de force push.
- Pas de commit direct sur `main`.
- Après l'accord : fast-forward de `main` sur la branche de session, puis push.
  La confirmation de `git push` demandée par `.claude/settings.json` s'applique.
- **Un seul commit par session** (squash si besoin).
- La branche de session est supprimée après le push.

## Conventions

- **Types de commit**
  - `feat` : capacité atteignable en production.
  - `chore` : code dormant (pas encore atteignable).
  - `refactor` : comportement inchangé.
- **Description** : à l'impératif, décrit la capacité observable, jamais le mécanisme.
- **Test né vert** = spec test : mutation obligatoire avant commit.
- **YAGNI** : on n'écrit que ce que la cible de la session exige.
- **Ordre** : la logique de `lib/` précède l'adaptateur de `src/`.
- **Dette et décisions** : `DEBTS.md` et `DECISIONS.md` sont mis à jour dans le commit
  de session.
