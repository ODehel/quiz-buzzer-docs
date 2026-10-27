# Buzz'O'Live : méthode de travail

Détail complet : `docs/method/WORKFLOW.md` (source de vérité).

## Rôles
- Claude fait le code, les tests et les docs, et exécute git.
- Olivier valide. Il ne code pas.

## Une session = un commit
Le titre de la session est le titre du commit.

## Ouverture
`git status` et `git log -5`. Arbre non propre ou branche autre que `main` : stop et le dire.
Puis branche `session/<titre-du-commit>`.

## Les deux portes
- **Porte 1 (cadrage)** : cible et choix de conception, ≤ 10 lignes. Rien d'écrit avant l'accord.
- **Porte 2 (revue)** : `git diff --stat`, résumé par fichier, points à challenger, section
  « ce que j'aurais pu faire autrement et pourquoi j'ai tranché ainsi ». Puis STOP.

## Interdit avant l'accord de porte 2
Aucun `git commit`, aucun `git push`. Sans « ok » explicite d'Olivier, on s'arrête.

## Règles git
- Staging fichier par fichier, jamais `git add .`.
- Pas de force push, pas de commit direct sur `main`.
- Après l'accord : fast-forward `main` sur la branche, puis push (confirmation demandée).
- Un seul commit par session.

## Le réel fait foi
Le handoff est une hypothèse. On le confronte à l'état réel à chaque ouverture ;
en cas d'écart, le réel gagne.

## Conventions de commit
`feat` (atteignable en prod), `chore` (code dormant), `refactor` (comportement inchangé).
Description à l'impératif, capacité observable, jamais le mécanisme.
