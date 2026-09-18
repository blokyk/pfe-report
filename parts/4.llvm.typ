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

== Validation par des tests unitaires

Notre passe d'optimisation sur le code Machine IR se situe au milieu du back-end et est généralement invoquée durant la fin de la compilation soit d'un fichier source C soit d'un fichier intermédiaire en LLVM IR ; il n'y a pas de format texte pour Machine IR exposé aux utilisateurs.
Dans tous les cas, nous ne pouvons pas complètement isoler notre optimisation du reste du flot de compilation, car dans un vrai programme beaucoup d'accès mémoire sont ajoutés ou éliminés durant les passes du middle-end et du back-end, et nous devons également nous assurer que les instructions `stlw` ne sont pas modifiées par des transformations tardives.

Inspecter l'exécution de notre passe de cache au milieu d'une exécution du back-end entier (invoqué avec l'outil `llc`) n'est pas complètement évident non plus, car les options principales activant des modes verbeux (spécifiquement `-debug` qui affiche les détails d'exécution des algorithmes et `-print-after-all` qui affiche le code du programme après chaque passe) sont _très_ verbeux et génèrent des fichiers de log de plusieurs milliers de lignes même pour des petits programmes source. Le format de ces logs est très variable et largement non documenté, assimilable à des séries de `print` internes à chaque passe.

L'approche la plus courante pour évaluer les programmes a donc consisté à, manuellement, invoquer clang pour générer un programme intermédiaire au format LLVM IR à partir d'un code C ; ensuite, exécuter `llc` avec une option pour s'arrêter avant notre passe `riscv-load-store-opt` ; puis inspecter le code Machine IR, et modifier le programme intermédiaire itérativement pour minimiser la taille des fonctions et ramener la complexité à un niveau abordable. (Prendre en main LLVM IR pour écrire des tests à partir de zéro aurait ajouté un coût trop significatif au travail du stage.)

#figure(
  caption: [Test unitaire d'un load et store consécutifs sur la pile, optimisable en un `STLW`.]
)[
  ```
  name: two_pairs_interlaced
  body: |
    bb.0:
      ; CHECK-LABEL: name: two_pairs_interlaced
      ; CHECK: $x1 = STLW $x2, 12
      ; CHECK-NEXT: $x10 = STLW $x3, 0 :: (load (s32))
      ; CHECK-NEXT: SW $x1, $x2, 12 :: (store (s32))
      ; CHECK-NEXT: SW $x10, $x3, 0 :: (store (s32))
      $x1 = LW $x2, 12 :: (load (s32))
      $x10 = LW $x3, 0 :: (load (s32))
      SW $x1, $x2, 12 :: (store (s32))
      SW $x10, $x3, 0 :: (store (s32))
  ```
]<lst_unit_interlaced>

Le résultat de cette minimisation est un ensemble de cas de test unitaires pour la passe d'optimisation du cache.
On peut les tester automatiquement car pour valider la correction de ses transformations et découvrir les bugs au moment où ils sont introduits, LLVM a une suite de tests unitaires de non-régression qui est validée par le testeur automatique `llvm-lit`, et inclut lui un système pour exécuter des passes individuelles.
Un exemple de ces test est montré dans le @lst_unit_interlaced : les lignes 9 à 12 décrivent le code avant la passe, constitué ici de deux paires load-store aliasées mais mélangées dans leur ordonnancement, et les lignes 5 à 8 décrivent le résultat attendu du test, où les instructions `LW` ou été correctement remplacés par des instructions `STLW` avec les mêmes opérandes.
Le test ne valide pas le fait que le premier `LW` est aliasé au premier `SW` et le second `LW` est aliasé au second `SW` ; cette information est implicite.

Nous validons la transformation sur des cas variés avec des instructions intermédiaires entre le load et le store, des inversions d'ordre (store puis load) qui sont exclus de l'optimisation, différents ordres d'instructions entre plusieurs paires aliasées, et différentes tailles d'accès entre autres.
Certains tests échouent car, comme discuté dans la @sec_design, l'analyse d'alias est incomplète et renvoie "les pointeurs sont peut-être aliasés" dans des cas où il n'y a pas en fait pas d'intersection d'adresse.
Ces écarts impliquent une légère perte de performances mais le programme reste correct, car la sémantique de `STLW` pour l'ISA est identique à `LW` : les différences sont micro-architecturales.
