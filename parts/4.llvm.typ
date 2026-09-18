#import "/utils.typ": *

= LLVM <sec_llvm>

== Que désigne vraiment "LLVM"

// https://github.com/llvm/llvm-project

LLVM est une infrastructure de compilation initialement publiée en 2004 @lattner2004llvm ; initialement le nom était un acronyme de _Low-Level Virtual Machine_ mais cette signification a été abandonnée quand le périmètre du projet s'est étendu avec le temps.
Aujourd'hui, c'est un projet sous l'égide duquel on trouve tous les composants d'une chaîne de compilation (comme décrite en @sec_design et plus encore) : un middle-end et ses back-ends vers de nombreuses architectures de CPU et même de GPU ("LLVM" au sens strict), un front-end C/C++ (clang), un nouveau middle-end expérimental (MLIR), un éditeur de liens (lld), debugger (lld), etc.
Tes ces sous-projets partagent des outils de bases, comme un langage de spécification déclaratif (TableGen), un harnais de test (llvm-lit), et des librairies de support.

#figure(
  caption: [Vue d'avion de la pipeline de compilation de LLVM.],
  image("/assets/compiler-pipeline.svg", width: 100%)
) <fig_llvm_pipeline>

Pour ce projet nous utilisons principalement le front-end C, clang ; le middle-end LLVM ; et le back-end RISC-V.
#todo[Pour des raisons techniques et hors de portée de ce rapport, on utilise la chaîne de compilation GNU (traditionnellement associée à GCC) pour faire l'édition des liens des programmes compilés.]
La @fig_llvm_pipeline montre une vue d'avion des différentes étapes de compilation, similaire aux @fig_comp_pipeline et @fig_comp_opt mais instanciée sur LLVM spécifiquement.

Le front-end clang compile le code source C vers la représentation intermédiaire la plus centrale de LLVM, _LLVM IR_, qui constitue le middle-end et où la majorité des optimisations complexes sont effectuées.
Les autres représentations font techniquement partie du back-end mais s'appuient très largement sur des représentations et algorithmes génériques, pas spécifiques à l'ISA RISC-V.
Explorer leur fonctionnement détaillé serait trop complexe pour ce rapport, mais on peut noter que le "SelectionDAG" représente le programme comme un _graphe_ (pour la sélection d'instructions) et que "Machine IR" est conceptuellement comparable à un langage 3-adresses utilisant un mélange d'instructions génériques et d'instructions RISC-V.

Comme nous avons décidé dans la @sec_design d'opérer à bas-niveau, nos modifications sont concentrées dans le back-end, à la fois pour la définition des nouvelles instructions `stlb`, `stlw`, etc. et pour la passe d'optimisation qui les génère à partir de `lb`, `lw`, etc.

== Ajout d'une instruction au back-end RISC-V

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
