#import "/utils.typ": *

= LLVM <sec_llvm>

== Que désigne vraiment "LLVM"

// https://github.com/llvm/llvm-project

LLVM est une infrastructure de compilation initialement publiée en 2004 @lattner2004llvm ; initialement le nom était un acronyme de _Low-Level Virtual Machine_ mais cette signification a été abandonnée quand le périmètre du projet s'est étendu avec le temps.
Aujourd'hui, c'est un projet sous l'égide duquel on trouve tous les composants d'une chaîne de compilation (comme décrite en @sec_design_compilers) et plus encore : un middle-end et ses back-ends vers de nombreuses architectures de CPU et même de GPU ("LLVM" au sens strict), un front-end C/C++ (clang), un nouveau middle-end expérimental (MLIR), un éditeur de liens (lld), debugger (lldb), etc.
Tous ces sous-projets partagent des outils de bases, comme un langage de spécification déclaratif (TableGen), un harnais de test (llvm-lit), et des librairies de support.

#figure(
  caption: [Vue globale de la pipeline de compilation de LLVM.],
  image("/assets/compiler-pipeline.svg", width: 100%)
) <fig_llvm_pipeline>

Pour ce projet nous utilisons principalement le front-end C (clang), le middle-end (LLVM), et le back-end RISC-V.
#todo[Pour des raisons techniques et hors de portée de ce rapport, on utilise la chaîne de compilation GNU (traditionnellement associée à GCC) pour faire l'édition des liens des programmes compilés.]
La @fig_llvm_pipeline montre une vue globale des différentes étapes de compilation, similaire aux @fig_comp_pipeline et @fig_comp_opt mais instanciée sur LLVM spécifiquement.

Le front-end clang compile le code source C vers la représentation intermédiaire la plus centrale de LLVM, _LLVM IR_, qui constitue le "middle-end" traditionnel, et où la majorité des optimisations complexes sont effectuées.
Les autres représentations font techniquement partie du back-end mais s'appuient très largement sur des représentations et algorithmes génériques, plutôt que des techniques spécifiques à l'architecture RISC-V.
Explorer leur fonctionnement détaillé serait trop complexe pour ce rapport, mais on peut noter que le "SelectionDAG" représente le programme comme un _graphe_ (pour la sélection d'instructions) et que "Machine IR" est conceptuellement comparable à un langage 3-adresses utilisant un mélange d'instructions génériques et d'instructions RISC-V.

Comme nous avons décidé dans la @sec_design_opti d'opérer à bas-niveau, nos modifications sont concentrées dans le back-end, non seulement pour la définition des nouvelles instructions `stlb`, `stlw`, etc. mais surtout pour la passe d'optimisation qui les génère à partir de `lb`, `lw`, etc.

== Ajout d'une instruction au back-end RISC-V

#let ft_td_flexibility = [
  Dans notre cas, on s'intéresse seulement aux instructions, mais TableGen peut être utilisé pour à peu près tout et n'importe quoi ; un utilisateur avec suffisamment de temps libre pourrait tout aussi bien utiliser TableGen comme un générateur de site statique en HTML/CSS.
]

#let ft_td_multitarget = [
  Par exemple, à partir d'un seul fichier TableGen, il est entièrement possible de générer à la fois une documentation HTML décrivant l'encodage et la sémantique de différentes instructions, _et_ un encodeur C++ pour ces instructions, _et_ un assembleur, etc.
]

Étant donné le nombre d'instructions des architectures modernes, une infrastructure de compilation de la taille de LLVM ne peut pas se permettre de redéclarer explicitement chaque information associée à chaque instruction ; la grande majorité des instructions ont bien plus en commun qu'elles n'ont de différences, et il devient donc assez rapidement apparent qu'un outil permettant de plus facile les décrire est nécessaire. Pour LLVM, cet outil s'appelle _TableGen_: c'est un DSL#footnote[Langage dédie ou langage domaine, lit. _Domain-Specialised Language_] permettant de définir de manière structurée des "modèles" (_templates_) paramétrables, qui peuvent ensuite être instanciés pour représenter des instructions#footnote(ft_td_flexibility) particulières. C'est essentiellement un langage de "macros", mais où les macros sont représentées par des classes avec des propriétés, où l'on peut mixer plusieurs macros, et où la "sortie" d'une définition TableGen est entièrement adaptable selon le besoin#footnote(ft_td_multitarget). Le @lst_tb_sample montre la définition pour l'instruction RISC-V `lw`, telle qu'elle apparaît dans LLVM (`llvm/lib/Target/RISCV/RISCVInstrInfo.td`) ; celle-ci s'occupe de définir à la fois l'instruction elle-même, son mnémonique, son encodage, et le fait que c'est une instruction load (en instanciant le modèle `Load_ri`), mais aussi des informations plus abstraites : ses propriétés de mémoire et d'ordonnancement sont également données, ainsi que ses attributs en matière d'optimisation.

#figure(
  caption: [Déclaration de l'instruction `lw` avec TableGen]
)[
  ```tablegen
  def LW  : Load_ri<0b010, "lw">, Sched<[WriteLDW, ReadMemBase]> {
    let IsSignExtendingOpW = 1;
    let canFoldAsLoad = 1;
    let isReMaterializable = 1;
  }
  ```
] <lst_tb_sample>

Une partie de ce qui fait la force de TableGen est bien sûr la capacité de définir ses propres modèles. Ainsi, tout comme LLVM déclare déjà un modèle `Load_ri` pour pouvoir facilement regrouper les loads basiques, nous pouvons définir nous même un modèle `StLoad`, qui permettra de factoriser les propriétés communes de nos nouvelles instructions. Le @lst_tb_stload démontre une version légèrement simplifiée de la définition de ce nouveau modèle, où l'on décrit non seulement l'encodage de notre instruction (en utilisant `RVInstI` comme modèle de base, qui utilise l'encodage type-I, et en décrivant l'opcode à la @lst_tb_stload_encoding), mais aussi ses opérandes (@lst_tb_stload_io) et sa syntaxe assembleur (@lst_tb_stload_asm).

#figure(
  caption: [Déclaration simplifiée du modèle `StLoad` qui sert de base à nos nouvelles instructions]
)[
  ```tablegen
   class StLoad<bits<3> funct3, string name>
      : RVInstI<
            funct3, OPC_CUSTOM_2, // #<lst_tb_stload_encoding>
            (outs GPR:$rd), (ins BasePtr:$rs1, simm12_lo:$imm12), // #<lst_tb_stload_io>
            name, "$rd, ${imm12}(${rs1})" // #<lst_tb_stload_asm>
        >
    {
      let hasSideEffects = false;
      let mayLoad = true;
      ... // ~5 lignes omises par souci de concision
    }
  ```
] <lst_tb_stload>

Avec ceci, nous pouvons définir nos nouvelles instructions aussi aisément que les loads basiques de RISC-V.

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
