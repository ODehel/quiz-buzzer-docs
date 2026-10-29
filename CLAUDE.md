# Buzz'O'Live : méthode de travail

Détail complet : `docs/method/WORKFLOW.md` (source de vérité).

## Rôles
- Claude fait le code, les tests et les docs, et exécute git via le dossier connecté.
  Il ne fait jamais `git push`.
- Olivier valide, lance les smoke tests et fait le `git push`. Il ne code pas.

## Une session = un commit
Le titre de la session est le titre du commit. Branche `session/<titre-du-commit>`.

## Ouverture
`git status` et `git log -5`. Arbre non propre ou branche autre que `main` : stop et le dire.
Puis branche de session.

## Les deux portes
- **Porte 1 (cadrage)** : proposée par Claude, ≤ 10 lignes. Rien d'écrit avant l'accord.
- **Porte 2 (revue)** : `git diff --stat`, résumé par fichier, sorties des smoke tests,
  points à challenger, section « ce que j'aurais pu faire autrement et pourquoi j'ai
  tranché ainsi ». Puis STOP.

## Interdit avant l'accord de porte 2
Aucun `git commit`. Sans « ok » explicite d'Olivier, on s'arrête.

## Règles git
- Staging fichier par fichier, jamais `git add .`.
- Pas de force push, pas de commit direct sur `main`, jamais de `git push` par Claude.
- Après l'accord : commit, fast-forward de `main`, suppression de la branche. Olivier pousse.
- Un seul commit par session.

## Smoke tests
Claude écrit un bloc PowerShell, Olivier le lance, la sortie va dans
`smoke-test-summary.txt` que Claude lit puis supprime.

## Le réel fait foi
Le handoff est une hypothèse. On le confronte à l'état réel à chaque ouverture ;
en cas d'écart, le réel gagne.

## Conventions de commit
`feat` (atteignable en prod), `fix` (correction), `chore` (code dormant, outillage),
`refactor` (comportement inchangé), `docs` (documentation seule).
Description à l'impératif, capacité observable, jamais le mécanisme.
