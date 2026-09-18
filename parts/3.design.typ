#import "/utils.typ": *

= Conception <sec_design>

Avec ce contexte et cette problématique établis, nous pouvons désormais nous tourner vers la conception d'une solution. Comme détaillé dans la section précédent, la thèse de Johan Söderström @johan_phd nécessite d'établir un moyen de communication entre le programmeur et le système de cache. Cependant, il n'est jusqu'ici pas évident quelle forme exacte cette communication devrait prendre. Cette section décrit la conception de cette solution d'un relativement haut niveau, et laisse aux sections @sec_llvm[] et @sec_gem5[] le rôle d'expliquer les détails d'implémentation.

== Expression du besoin de l'utilisateur <sec_design_input>

Avant de réfléchir à une forme de communication destinée au cache, il faut d'abord réfléchir à une forme destinée au programmeur lui-même. En effet, bien que les résultats finaux soient souvent les mêmes, les programmes modernes sont écrits dans une myriade de langages différents qui ont, pour la plupart, pour but d'exprimer au mieux les désirs et idées de l'utilisateur. Une partie de cet objectif requiert d'inférer plus ou moins d'informations sur le comportement voulu par le programmeur. Par exemple, là où certains langages se réservent entièrement le choix de moyen de stockage de données en mémoire (tel que JavaScript, Python), d'autres demandent d'expliciter la démarche d'allocation (tel que C, Zig), et d'autres encore laissent le choix à l'utilisateur tout en ayant des moyens de l'influencer (par ex. ```c register``` en C permettant d'explicitement stocker une valeur en registre, tandis que le reste des valeurs peuvent être stockées soit en registre, soit en pile, à la liberté de l'implémentation).

#let ft_local_opt = [
  Dans la plupart des cas, en emplacement mémoire est lu soit à proximité de là où il écrit (par ex. dans la même fonction), soit très loin de son écriture. Bien que le deuxième cas soit plus épineux à détecter (il requiert potentiellement de l'analyse inter-fonctions ou globale), il est aussi peu intéressant pour notre optimisation, puisque celle-ci est seulement
  applicable pour des valeurs qui restent en cache entre leur lecture et leur écriture.
]

Dans notre cas, il est important de préciser que, idéalement, l'utilisateur n'aurait pas besoin d'indiquer quels accès mémoire devraient être optimisés. En effet, en théorie, le compilateur devrait pouvoir détecter automatiquement quelles lectures sont susceptibles d'être suivis par des écritures peu de temps après, surtout étant donné que c'est une information généralement locale#footnote(ft_local_opt). En plus de cela, il est souvent difficile pour l'utilisateur de savoir où exactement dans son programme il y a des accès mémoires, et il serait encore moins pratique de devoir chacun les disséquer pour les annoter.

Ainsi, il semblerait que la manière la plus idéale d'implémenter cette solution est de manière transparente à l'utilisateur : les lectures qui sont suivies d'écritures seront détectées automatiquement par le compilateur, sans annotation ou action du programmeur.

== Format de l'information communiquée au processeur

Maintenant que nous avons établi comment le logiciel exprimera sa connaissance du comportement des accès mémoire du programme, on peut se tourner à la communication de cette information envers le système de cache.

Quand il en vient à communiquer au matériel une information que le programmeur a et que le processeur ne peut pas deviner, la solution classique est un _hint_ (lit. un indice) : une instruction qui n'a aucun autre effet que de fournir une information à la CPU pour que celle-ci adapte subtilement son comportement. Ces _hints_ sont même généralement des ré-interprétations d'instructions existantes n'ayant précédemment aucun effet. Par exemple, l'extension RISC-V `Zihintntl` spécifie qu'une instruction `ADD` ayant comme destination `x0` (un registre immutable) et comme sources `x0` et `x5` devrait être traitée comme un  indice que le programmeur _sait_ que les opérandes mémoire de l'instruction suivante n'ont pas d'intérêt à être mises en cache. Un des désavantages de cette approche est la nécessité de stocker encore plus d'informations micro-architecturales, et de définir exactement l'interaction que cela aura avec d'autres états et indices (et c'est sans parler de l'interaction avec l'exécution out-of-order). Cette approche augmente donc la complexité d'implémentation pour le matériel, mais est plus flexible et facile à implémenter côté logiciel.

L'autre choix commun est de créer une variation d'une instruction existante. En effet, "l'espace d'instructions RISC-V", c'est-à-dire l'ensemble des possibilités d'encodages d'instructions RISC-V, est aménagé de manière à laisser amplement assez de "place" pour pouvoir ajouter de nouvelles instructions. Par exemple, l'extension `Zalrsc` introduit une variation de l'instruction `LW` (servant à charger un _word_ de 32-bits), en réutilisant le même format et les cinq derniers bits de l'encodage, mais en changeant uniquement l'opcode principal. Ceci requiert donc potentiellement d'ajouter un grand nombre d'instructions (il faut généralement faire une variation de chaque déclinaison de l'instruction originale), mais, peut-être contre-intuitivement, elles sont cette fois-ci plus faciles à implémenter en matériel. En effet, ces nouvelles instructions ne requièrent pas de stocker plus d'état persistent, qui n'aura donc pas non plus de risque d'interagir avec d'autres instructions, etc. Elles peuvent aussi très souvent réutiliser une grande partie des composants matériels internes déjà existants, et ont donc également un moindre coût physique.

Étant donné le manque de compétence que j'avais pour l'implémentation matérielle, essayer d'ajouter des _hints_ aurait présenté un bien plus gros problème qu'une variation d'instruction existante. Le sujet de ce stage était déjà suffisamment complexe, donc il a été décidé que la deuxième solution serait plus désirable dans ce cas.

Donc, pour que le programmeur puisse communique au processeur qu'une lecture à un emplacement mémoire sera bientôt suivi d'une écriture au même endroit, on ajoutera de nouvelles instructions reflétant les instructions _load_ de base. Celle-ci seront nommées `stlb`, `stlw`, etc., correspondantes aux instructions `lb`, `lw`, etc. qui définissent des lectures mémoire de différentes tailles et extensions de signe.

== La pipeline de Babel <sec_design_compilers>

Bien que nous ayons mentionné rapidement l'idée d'une passe d'optimisation lors de la @sec_design_input, les détails de son rôle sont encore flous. Nous avons parlé du langage qu'utilise le programmeur, mais il nous reste à parler de son traducteur : le _compilateur_. C'est l'outil qui permet à l'utilisateur de transformer la représentation de son programme en un langage source vers un langage plus bas-niveau, généralement le langage machine.

#figure(
  caption: [Une vue _extrêmement_ simplifiée des trois étapes d'un compilateur.],
  image("/assets/compiler.svg", width: 75%),
  placement: top
) <fig_comp_pipeline>

Historiquement les compilateurs traduisaient directement le code source dans le langage cible (dans notre cas l'assembleur RISC-V), mais cette approche ne passe pas à l'échelle quand le nombre de langages source et d'architectures cible augmentent. C'est ce qui a motivé l'introduction des _représentations intermédiaires_, structurant le compilateur en trois étapes illustrées dans la @fig_comp_pipeline :
  + Le _front-end_ compile le langage source vers la représentation intermédiaire du compilateur
  + Le _middle-end_ effectue un maximum de transformations communes
  + Le _back-end_ compile enfin la représentation intermédiaire vers le langage cible

L'intérêt est d'implémenter une seule fois les transformations complexes dans le middle-end, et de réutiliser cette infrastructure avec toutes les combinaisons souhaitées d'un front-end et d'un back-end. Nous n'utiliserons que le front-end C et le back-end RISC-V pour nos expériences, mais la structure du compilateur limite nos options pour implémenter l'optimisation du cache.

En effet, le long de ce pipeline centré sur une, et même, de fait, _plusieurs_ représentations intermédiaires, les informations _sémantiques_ ("haut-niveau") du programme source sont progressivement érodées et remplacées par des informations _opérationnelles_ ("bas-niveau") instruisant précisément le processeur sur l'exécution du programme, illustré sur la @fig_comp_opt.

#figure(
  caption: [Zoom sur le middle-end et la perte progressive des informations source.],
  image("/assets/compiler-ir.tight.svg", width: 100%)
) <fig_comp_opt>

Le code généré par le front-end est typiquement très inefficace et passe donc à travers diverses optimisations, telles que l'élimination du code mort (_Dead Code Elimination_). En plus de ces optimisations, plusieurs descentes en abstraction modifient en profondeur la représentation du programme ; par exemple la sélection d'instructions passe d'une représentation avec des opérations génériques (par ex. "lecture d'un entier à l'adresse $y$"), à une représentation avec des instructions RISC-V (par ex. ```asm lw x7, 16(x6)```).

C'est là qu'on voit la dualité fondamentale de cette pipeline : les transformations qui veulent accéder à des informations structurées ou annotées dans le code source doivent se faire tôt, dans les couches hautes ; à l'inverse, les transformations qui ont besoin de contrôle fin sur les instructions émises dans le programme assembleur doivent se faire tard, dans les couches basses. C'est une autre raison d'écarter l'idée d'annotation déclenchant cette transformation dans la @sec_design_input : elle nécessiterait de transporter les annotations émises à haut-niveau vers le code bas-niveau ; cette tâche est suffisamment complexe pour nécessiter plusieurs années de recherche @seb_llvm pour "seulement" quelques informations basiques.

== Solution retenue : pour la compilation <sec_design_opti>

Étant donné cette limitation, nous devons désormais faire un choix exact d'où, sur ce spectre d'informations, placer notre nouvelle optimisation. Pour rapel, cette optimisation doit pouvoir détecter les lectures à partir d'emplacements mémoire sur lesquels on écrit un peu plus tard. Notons d'abord les prérequis de cette optimisation :
  + elle doit pouvoir inspecter n'importe quelle lecture mémoire, c.-à-d. que n'importe quel instructions load du binaire final (et de même avec les _écritures_ en mémoire)
  + elle doit pouvoir savoir quelles instructions sont susceptibles de s'exécuter après une certaine autre instruction (ce qui n'est pas trivial avec la structure graphique et cyclique de certaines représentations intermédiaires en jeu)
  + elle doit pouvoir remplacer, de manière durable, une instruction spécifique avec une autre instruction
  + elle doit pouvoir établir qu'une paire de lecture-écriture en mémoire accède au même emplacement

Ces conditions sembleraient presque toutes pointer vers une optimisation très bas-niveau, étant juste avant la génération des instructions RISC-V finales. Cependant, à première vue, le prérequis (4) va bien plus nous gêner : une fois sous forme d'instruction, il est difficile de s'assurer que deux instructions accèdent à la adresse. En effet, malgré les apparences, il est impossible de savoir si ```asm ld x4, 8(x2)``` et ```asm ld x5, 8(x2)``` chargent réellement le même emplacement, car sans analyser l'entièreté des instructions _entre_ ces deux `ld`, il est impossible de s'assurer que la valeur de `8(x2)` n'a pas changée entre les deux.

#let ft_alias = [
  "Alias" étant ici le terme pour désigner deux expressions qui sont en réalité deux "noms" différents pour une même adresse ou valeur.
]

Ce problème est exactement ce que l'analyse d'alias#footnote(ft_alias) tente de résoudre : pouvoir établir que deux valeurs se réfèrent à la même adresse mémoire, en prenant compte d'une quantité arbitraire de code entre les deux expressions. Malheureusement, comme toute propriété non-triviale, cette analyse ne peut jamais être exacte, car elle est victime du théorème de Rice @rice_theorem et est donc indécidable @undecidable_aa. Dans notre cas, l'inexactitude des résultats n'est pas catastrophique : si on est trop pessimiste (c.-à-d. qu'on ignore des paires aliasées), on rate juste des gains de performances potentiels ; si on est trop optimiste (c.-à-d. qu'on détecte des alias là où il n'y en a pas), on a une chance de légèrement ralentir le cache dans des situations multicoeur, mais dans tous les cas le programme reste correct et la dégradation de performances est limitée.

Il est donc maintenant évident que le seul emplacement possible pour notre optimisation est le plus proche possible de la dernière passe de génération d'instructions RISC-V. Celle-ci itèrera à travers chaque paire d'un load et d'un store, vérifiera si ceux-ci se réfèrent à un même emplacement mémoire, et si c'est le cas, remplacera le load original par notre nouvelle instruction équivalente.

== Solution retenue : pour l'évaluation par simulation <sec_design_hw>

Évidemment, pouvoir générer ces instructions ne suffit pas. L'autre partie de ce stage est aussi d'évaluer l'impact sur les performances d'exécution d'un programme. Dans un monde idéal, cela se ferait sur un réel système, avec un processeur modifié pour supporter nos `stlw`, pour nous donner des mesures exactes de gains de performance réalistes. Cependant, en pratique, ce type de tests ne serait pas forcément aussi utile qu'on aimerait le croire.

La conception de micro-processeurs est un domaine qui exige un niveau de technicité élevé, et même des minuscules modifications peuvent vite engouffrer des semaines entières dans une chasse aux bugs infinie. De plus, même avec tout le savoir au monde, le temps d'itération est souvent très long, certains designs pouvant prendre des heures à synthétiser malgré leurs petites tailles. Ainsi, l'idée de tester directement sur du matériel n'est pas envisageable.

#let ft_dont_even_think_abt_it = [
  Une leçon que j'ai déjà apprise lors mon dernier stage, après avoir innocemment essayé d'utiliser un design de processeur vectoriel pour tester du code que j'avais écrit dans le cadre de mon sujet. J'ai heureusement vite remarqué les sables mouvants dans lesquels je m'étais enlisée, et m'en suis échappée.
]

L'option la plus proche de tester sur du hardware était bien sûr de _simuler_ l'exécution d'un design de processeur, à l'aide d'un simulateur de HDL tel que Verilator. Ceci augmente généralement la vitesse d'itération, et apporte bien plus d'outils de debuggage et diagnostics. Cependant, il y a toujours le problème qu'un micro-processeur n'est pas trivial : tenter de simplement _explorer_ un design d'un _composant interne_ d'un processeur est déjà une tâche gargantuesque#footnote(ft_dont_even_think_abt_it).

La seule alternative restante était donc d'utiliser un simulateur _logiciel_. Ici, nous n'avons pas de design concret de micro-processeur, mais plutôt un modèle approximatif du fonctionnement _général_ de sa micro-architecture. On ne peut donc pas évaluer la performance aussi fidèlement, bien sûr, mais il reste toujours possible de faire des mesures _qualitatives_. Par exemple, un test sur simulateur qui relève un gain de performance de 4% ne signifie pas qu'on gagnera réellement 4% sur un processeur en pratique, mais cela nous indique un ordre de grandeur : on peut sûrement s'attendre à avoir des gains de plus de 1%, mais pas plus de 10%. Pour notre cas, d'une exploration initiale servant surtout à guider et informer une thèse, ce genre d'information suffit largement, donc un simulateur micro-architectural est parfait.

Il existe une kyrielle de simulateurs de ce genre selon les domaines exacts, mais, dans notre cas, nous avons spécifiquement besoin de modéliser précisément à la fois le système de cache _et_ l'exécution du processeur. Le simulateur le mieux équipé pour cela est gem5, que nous explorerons plus en détail dans la @sec_gem5.

Nous aurons alors pour tâche d'y ajouter non-seulement le support de nos nouvelles instructions, mais aussi potentiellement de modifier le système de cache et ses protocoles de cohérence pour que ceux-ci réagissent correctement à nos instructions.
