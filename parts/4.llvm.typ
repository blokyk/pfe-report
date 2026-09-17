= llvm <sec_llvm>

== que désigne vraiment "LLVM"

- une collection de composants qui agissent à différentes étapes de la pipeline de compilation (cf @sec_design)
- un très bon outillage inter-projet (e.g. tablegen, llvm-lit, utils pour printf-debug facilement)

== ajouter une instruction

- facile grâce à tablegen
  - pas besoin d'expliquer le langage, mais juste un extrait simplifié d'une instr (comme j'ai fait pour les slides)
- il faut réfléchir un peu à l'encodage, mais pas dur non plus
  - maybe plutôt en annexe?

== ajouter une opti dans llvm

// - l'analyse d'alias est facilement accessible dans llvm, youpi!
// Cependant, cette indécidabilité n'est pas le seul problème avec l'analyse d'alias : sans surprise, les différents algorithmes @type_aa @svf_aa @dyck_aa tentant de l'implémenter sont en plus très complexes. Heureusement, LLVM inclut déjà une multitude d'implémentation, dont il combine les résultats en une seule API, notamment la classe `AAResult`.

- trois choix:
  - nouvelle opti hors-llvm
  - nouvelle opti dans llvm
  - modification d'opti dans llvm
- j'ai choisi de modifier une opti existante, parce que plus facile, rapide, et mieux testé
- il fallait faire gaffe de bien transférer toutes les infos, car autrement on a des mauvais/faux résultats avec l'AA

== validation (ajouter des tests)

- même si les outils llvm sont très bien, ils manquent de documentation à jour, surtout sur les parties plus bas-niveau
- notamment llc est très peu documenté et un peu dur à utiliser (beaucoup de trial-and-error pour réussir à avoir un fichier à tester)
- les outils bas-niveau émettent beaucoup de données, qui sont souvent assez obscures, donc c'est dur de minimiser les tests
- pour les scénarios plus "exotiques," il faut soit beaucoup de contexte/extra code, soit il faut mettre les mains dans le cambouis et essayer de tweak un test existant (autant ses instrs que ses métadonnées, qui sont encore plus obscures) jusqu'à ce qu'il fasse ce qu'on veut
