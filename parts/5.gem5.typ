#import "/utils.typ": *

= gem5 <sec_gem5>

Comme mentionné dans la @sec_design_hw, le côté "hardware" de ce projet ne pouvait, en pratique, pas être testé sur du vrai matériel. Ainsi, pour la simulation, le simulateur gem5 @gem5-src @gem5-src-20 était un choix évident. Cependant, c'est bien plus qu'un simple émulateur, et sa prise en main a été une partie majeure de mon stage.

== Le Zen de gem5

#let ft_hdls = [
  "Hardware Description Language", un terme générique pour designer les langages permettant de concevoir et décrire des composants matériels. Cette description se fait généralement en utilisant le "Register Transfer Level", où l'on définit le composant en termes de transferts de données et de signaux, en faisant abstraction des détails temporaux et électroniques de l'implémentation finale.
]

#let ft_sim_def_nuance = [
  Bien sûr, cette distinction est partiellement arbitraire : il n'est jamais vraiment possible de simuler un composant physique jusque dans ses détails physiques les plus exacts sans simplement créer un objet physique identique. Étant donné que l'objectif primaire de gem5 est la recherche micro-architecturale, celui-ci modélise un vaste nombre de mécanismes internes de CPU modernes, sans avoir besoin de s'abaisser jusqu'au niveau de signaux ou registres individuels comme serait fait en HDL#footnote(ft_hdls).
]

gem5 résulte d'un mariage entre un simulateur micro-architectural, `m5`, et un simulateur mémoire, `gems`. Il est important de noter ici la différence entre _émulateur_ et _simulateur_ : là où un émulateur tente de reproduire le comportement _externe_ d'un système donné, sans se soucier de ses détails d'implémentation, un simulateur a plutôt pour but de calquer et modéliser le comportement _interne_ d'un système#footnote(ft_sim_def_nuance).

Par exemple, QEMU @qemu_2005 est un _émulateur_ qui a pour but de reproduire le comportement externe d'un type de processeur (par ex. ARM) sur un autre (par ex. x86), en traduisant les instructions d'une architecture vers l'autre ; cependant, il est impossible de savoir, même approximativement, la durée d'exécution originale (c.-à-d. sur sa plateforme d'origine, par ex. ARM) d'un programme donné à partir de son exécution à travers QEMU, puisque ce dernier ne modélise pas les particularités du processeur ou les timings du système mémoire. Au contraire, avec gem5, il est possible d'avoir une estimation raisonnable du temps qu'aurait pris une invocation, car celui-ci est conçu de manière à reproduire les mécanismes internes des CPUs modernes.

Bien sûr, il y a une myriade de manières de concevoir un processeur, donc gem5 ne simule pas qu'une seule micro-architecture, mais vise plutôt à offrir un framework modulaire pour définir ou modifier différents types de CPUs. Le projet officiel offre actuellement une multitude de modèles, chacun optimisés pour différents scénarios ; les principaux sont :
  - *`TimingSimpleCPU`*, simulant un processeur "in-order" utilisant un contrôleur mémoire qui modélise de manière détaillée le timing des requêtes mémoires, ainsi que leurs utilisations de ressources micro-architecturales ; utile pour étudier de manière précise et reproductible le comportement du système sur seulement un petit bout de code.
  - *`MinorCPU`*, simulant également un processeur "in-order", mais son modèle d'exécution offre une bien meilleure flexibilité de configuration, permettant d'approximer le fonctionnement interne d'une grande quantité de CPUs réelles ainsi que d'explorer de nouvelles techniques de conception.
  - *`O3CPU`*, simulant un processeur "out-of-order" (aka OoO, aka O3), avec un modèle d'exécution extrêmement détaillé (en particulier, il est basé sur l'Alpha 21264, notamment son mécanisme de prédiction de branche), mais moins de customisation

Chacun de ces modèles (et bien d'autres non mentionnés) sont implémentés en C++ et faits pour être facilement modifiables. Pour pouvoir modéliser au mieux les communications entre chaque composant micro-architectural, ces implémentations sont constituées d'objets indépendants et interchangeables, qui échangent des paquets, des messages, des signaux, qui utilisent des files d'attentes, qui peuvent seulement prendre un nombre limité d'actions par cycle, etc.

La @fig_gem5_cpu donne une vue d'ensemble des différents types de communications et d'intégrations entre les composants du coeur de CPU et du système mémoire.
Le processeur est centré autour du décodeur, qui est généré à la compilation de gem5 à partir d'une description de l'ISA dans un DSL, et de l'unité d'exécution, qui contrôle l'état du processeur, modifie les registres, et déclenche les accès mémoire.
Tous les composants qui interagissent dans le système mémoire le font à travers des paires de *ports*, toujours constituées d'un "port maître" et d'un "port asservi", qui contiennent une file bidirectionnelle.
Lorsque le processeur déclenche un accès mémoire il construit une *requête* qui est ensuite transportée par le système mémoire dans le réseau de ports par des échanges de *paquets*, qui sont essentiellement des interactions mémoire point-à-point permettant, en agrégat, d'amener la requête à son destinataire et de rapatrier la réponse.

#figure(
  caption: [Représentation simplifiée des échanges CPU/mémoire dans gem5 (basée sur #link("https://gem5bootcamp.github.io/gem5-bootcamp-env/modules/developing%20gem5%20models/instructions/")[[1]], #link("https://www.gem5.org/documentation/general_docs/ruby/")[[2]]).],
  { image("../assets/gem5-cpu-memory-system.svg")
    "Notation des files de paquets entre chaque paire de ports :"
    image("../assets/gem5-queues.svg") }
) <fig_gem5_cpu>

== Implémenter une nouvelle technique... ou pas ?

Un des problèmes majeurs avec cette architecture, que nous avions déjà relevé dans la @sec_design_hw mais que la @fig_gem5_cpu expose au grand jour, est que le composant (qui est juste un morceau de code) responsable de l'exécution des instructions est fortement découplé de celui qui gère le système mémoire. Le décodeur ne peut pas simplement appeler une fonction du système de cache, mais doit au contraire passer à travers plusieurs interfaces de communication, avec multiples couches d'encapsulation et d'abstraction. Ainsi, une simple lecture mémoire doit d'abord être décodée par l'unité d'exécution, puis ce dernier doit envoyer un paquet (potentiellement avec certains flags) contenant une requête (elle aussi avec certains autres flags) destinée au contrôleur mémoire du processeur, qui sera généralement ensuite traduite en une représentation interne (toujours avec différents flags) puis transmise au système de cache.

En théorie, pour implémenter nos plans originaux de la @sec_design_hw, nous aurions donc besoin d'effectuer les modifications suivantes :
  + durant le décodage, annoter que cette instruction traite son opérande mémoire différemment
  + au moment de l'exécution, on ajoute un flag spécifique à la requête mémoire pour signaler que le cache doit modifier son comportement
  + à la réception de la requête, traduire le flag attaché à celle-ci en un flag compris à l'intérieur du contrôleur mémoire
  + puis au bout d'un moment, traduire et transmettre à nouveau ce flag en un format compréhensible par le système de cache
  + enfin, ajouter le support pour ce flag dans le cache, qui adaptera son comportement

Pour ajouter à cette complexité, ces changements nécessiteraient en plus de manipuler trois langages différents : en plus du C++ utilisé dans le reste de la base de code, le décodeur est décrit dans un DSL#footnote[Langage dédie ou langage domaine, lit. _Domain-Specialised Language_] _ad-hoc_, et les protocoles de cache sont eux spécifiés dans un _autre_ DSL _ad-hoc_ (appelé "SLICC"), à l'aide de machines à état et de files de messages.

#let ft_gem5_docs = [
  Documentation qui est, d'ailleurs, souvent obsolète, incomplète, ou même inexistante, et est éparpillée en une kyrielle de forme (référence technique, documentation traditionnelle, tutoriels, cours, slides, exercices, _autre_ référence technique, etc.) ; peut-être ont-ils pris la carte de #link("https://diataxis.fr/")[Diátaxis] un peu trop littéralement ?
]

Ainsi, une des premières tâches de mon stage a été de vérifier lesquelles de ces étapes étaient réellement nécessaires. Cette étape était beaucoup plus "floue" que les autres : elle consistait surtout à lire la documentation des différents composants de gem5#footnote(ft_gem5_docs), et à naviguer le code en espérant y trouver une indication d'où ces modifications devraient être (soit en cherchant des "mots-clés", soit en essayant de tracer le chemin d'exécution).

Il est assez vite devenu apparent qu'un concept similaire existait pour les architectures x86 et ARM, représenté par un flag de requête nommé `Request::READ_MODIFY_WRITE`. Cependant, celui-ci semblait uniquement être utilisé, sur ces plateformes, pour des instructions atomiques, ce qui n'est pas le cas de notre instruction. Il a donc été nécessaire de creuser plus profond. D'abord, il fallait s'assurer qu'une instruction avec ce flag ne serait pas traitée comme atomique par le système mémoire, et ne le mettrait pas non plus dans un état invalide. Ensuite, il fallait vérifier que la "traduction" (mentionnée plus haut) de la requête en représentation interne ne perdrait pas l'information dans le cas où ce n'est _pas_ une opération atomique. Enfin, il a fallu suivre de près l'implémentation du protocole CHI pour vérifier que celui-ci se comporterait correctement en présence de ce flag. Ce dernier point était particulièrement épineux, étant donné la complexité du protocole, le nombre d'états différents, l'étendue du code (plus de 12 000 lignes), et le langage SLICC lui-même qui requiert souvent du contexte caché (par ex. des variables générées par le "compilateur" SLICC, ou encore des détails d'implémentation du système mémoire) pour être compris.

#let ft_rmw_store = [
  Bien qu'elles soient comptabilisées en interne comme des _écritures_ en mémoire, ceci n'affecte pas le réel comportement du système, mais simplement les statistiques recueillies automatiquement. En réalité, l'effet sur les statistiques de ce "bug" a justement été un des indices que nous étions sur la bonne voie en terme d'implémentation du design.
]

Cependant, après plusieurs semaines de recherches et tests, il est vite devenu clair qu'en réalité, tout était déjà en place pour pouvoir tester notre design initial : l'instruction n'était pas catégorisée comme atomique juste à cause de ce flag, le système mémoire était capable de traduire correctement des requêtes le contenant#footnote(ft_rmw_store), et CHI était déjà capable de modéliser cette situation sans modification. La seule tâche restante était alors d'ajouter le support pour notre instruction, et de lui attacher le bon flag. Pour ceci, il suffisait de modifier le fichier spécifiant le décodeur RISC-V, `src/arch/riscv/isa/decoder.isa`. Le DSL utilisé par celui-ci est assez peu documenté, mais le code à ajouter est surprenamment simple : le @lst_gem5_decoder_patch montre la spécification de notre instruction `stlb`, où l'on utilise `mem_flags` pour spécifier que la requête mémoire doit avoir le flag donné, le fameux `READ_MODIFY_WRITE` (une meilleure explicitation du DSL est hors de portée de ce rapport).

#figure(
  caption: [Un extrait du code ajouté au décodeur RISC-V de gem5 pour supporter une de nos nouvelles instructions, `stlb`.]
)[
  ```ts
  0x16: decode FUNCT3 {
    format Load {
      0x0: stlb({{
        Rd_sd = Mem_sb;
      }}, mem_flags = READ_MODIFY_WRITE);
      ...
  ```
] <lst_gem5_decoder_patch>

== Configuration et simulation avec gem5

#let ft_cpp_py_classes = [
  Ces classes Python sont le plus des `SimObject`s, qui correspondent à des classes C++ et qui permettent de faire le lien entre la configuration décrite en Python (dont par ex. les connexions des différents composants) et la réelle implémentation de chaque composant. Par exemple, c'est le cas de `m5.objects.RiscvCPU.RiscvTimingSimpleCPU` (utilisée dans le @lst_base_gem5_conf), qui est en réalité un _wrapper_ autour de `gem5::TimingSimpleCPU`, définie dans le fichier `src/cpu/simple/timing.hh`.
]

Bien que la plupart du code gem5 soit écrit en C++ (un peu plus de 88%), l'interface publique de gem5 est en Python: la mise en place d'une simulation se fait en instanciant des objets de différentes classes Python#footnote(ft_cpp_py_classes), représentant chacun différents composants du système à simuler. Il est possible de régler manuellement chaque composant individuel et de les "raccorder" comme on le souhaite, mais il existe aussi des classes utilitaires telles que `RiscvBoard` lorsqu'on désire une configuration basique. Par exemple, le @lst_base_gem5_conf crée un système avec un processeur mono-coeur 1GHz RISC-V utilisant le modèle `TimingSimpleCPU`, 1Go de RAM DDR3 1600 MHz, et aucun cache, grâce à la classe `RiscvBoard`, qui s'occupe d'établir les connections et d'initialiser chaque composant lors de la simulation.

#figure(
  caption: [Une configuration basique d'un système RISC-V.]
)[
  ```py
  from gem5.components.boards.riscv_board import RiscvBoard
  from gem5.components.cachehierarchies.classic.no_cache import NoCache
  from gem5.components.processors.base_cpu_core import BaseCPUCore
  from gem5.components.processors.base_cpu_processor import BaseCPUProcessor
  from gem5.components.memory.single_channel import SingleChannelDDR3_1600
  from gem5.isas import ISA

  from m5.objects.RiscvCPU import RiscvTimingSimpleCPU

  board = RiscvBoard(
    clk_freq = "1GHz",
    processor = BaseCPUProcessor(
      BaseCPUCore(RiscvTimingSimpleCPU(), isa = ISA.RISCV)
    ),
    memory = SingleChannelDDR3_1600("1GiB"),
    cache_hierarchy = NoCache()
  )
  ```
] <lst_base_gem5_conf>

Ce code permet de décrire le système que l'on veut simuler, mais il nous reste encore à lancer la simulation, ce qui implique également d'initialiser le code qu'exécutera le système. Ceci peut paraître être trivial, mais là encore se cache un autre choix qu'offre gem5, qui supporte deux modes d'exécution différents :
  - *Full-System* (FS) simule exactement l'entièreté du démarrage du système matériel, s'occupant seulement de charger l'image du noyau en mémoire mais n'intervenant pas pour le reste de la simulation.
  - *Syscall Emulation* (SE), comme son nom l'indique, ne cherche pas à simuler un réel système d'exploitation, mais uniquement de permettre à un binaire "userland" d'être exécuté, en laissant gem5 la responsabilité d'émuler les appels systèmes.

#let ft_se_debugging = [
  Un autre avantage non-négligeable du _SE_ est la facilité de débeugage : en plus de pouvoir itérer plus rapidement sur une simulation plus rapide et plus facilement mise en place, il est aussi bien plus pratique d'examiner les logs de debug et traces d'exécution des différents composants en mode _SE_. En effet, puisqu'il n'y a pas de système d'exploitation entier à exécuter, le nombre d'opérations est considérablement plus petit, ce qui rend plus facile la tâche d'isoler exactement la partie qui nous intéresse et à quelle portion du programme elle correspond.
]

Le premier mode est utile lorsque l'interaction entre le système "matériel" et le système d'exploitation est important à l'expérience en cours, mais il peut être très dur à mettre en place (entre configurer le matériel correctement, et générer les images noyaux et disques à utiliser, il y a beaucoup de petites étapes où une faute peut facilement se glisser et saboter le résultat final), en plus d'être bien plus lent à simuler. Le second mode, lui, permet d'exécuter des programmes conçus pour fonctionner en "userland", c'est-à-dire non pas en tant que noyau, mais en tant qu'application classique, faisant des appels systèmes pour interagir avec le monde externe (par ex. lire un fichier, démarrer une connexion, etc.) ; ceci requiert moins de configuration, et si l'expérience en question demande seulement d'exécuter un simple binaire, alors cela sera bien plus rapide en _Syscall Emulation_ qu'avec un démarrage et noyau entièrement simulé avec le mode _Full-System_#footnote(ft_se_debugging).

Le @lst_base_gem5_run démontre les additions nécessaires au @lst_base_gem5_conf pour charger un binaire `hello.rv64` en mode _Syscall Emulation_ sur notre système, et pour lancer la simulation jusqu'à sa complétion. Étant donné qu'il est exécuté en _SE_, `hello.rv64` peut faire appels à des fonctions systèmes telles que `write(2)` ou `_exit(2)`, et ceux-ci seront gérés correctement par gem5.

#figure(
  caption: [Un exemple de code permettant de lancer une simulation en _Syscall Emulation_.]
)[
  ```py
  ...

  binary = BinaryResource(local_path="./hello.rv64", id="hello")

  board.set_se_binary_workload(binary)
  sim = Simulator(board=board)
  sim.run()
  ```
] <lst_base_gem5_run>

Avec ces outils en main, nous pouvons désormais mettre en place les conditions dans lesquelles nous souhaitons dérouler nos tests. Étant donné que l'on souhaite surtout observer le comportement du cache, sans forcément s'intéresser à son interaction avec le modèle d'exécution du processeur, nous utiliserons un coeur basé sur `TimingSimpleCPU`, ce qui nous permettra notamment de mesurer précisément les éventuels gains de performance temporelle qu'apporte notre optimisation. Ensuite, il faut établir la composition de nos caches : nous savons déjà que nous utiliserons le protocole de cohérence CHI, et gem5 offre deux implémentations pré-faites de hiérarchies CHI ; nous choisirons une hiérarchie avec deux niveaux de cache privés, de respectivement 16Kio et 128Kio chacun. La configuration finale correspondante à cette description est présentée dans le @lst_final_gem5_conf.

#figure(
  caption: [La configuration utilisée pour les expériences au travers du stage.]
)[
  ```py
  from gem5.isas import ISA
  from gem5.components.boards.riscv_board import RiscvBoard
  from gem5.components.cachehierarchies.chi.private_l1_private_l2_cache_hierarchy  import PrivateL1PrivateL2CacheHierarchy
  from gem5.components.processors.base_cpu_core import BaseCPUCore
  from gem5.components.processors.base_cpu_processor import BaseCPUProcessor

  from m5.objects.RiscvCPU import RiscvTimingSimpleCPU

  board = RiscvBoard(
    clk_freq  = "1GHz",
    processor = BaseCPUProcessor(
      BaseCPUCore(RiscvTimingSimpleCPU(), isa = ISA.RISCV)
    ),
    memory = SingleChannelDDR3_1600(),
    cache_hierarchy = PrivateL1PrivateL2CacheHierarchy(
      l1i_size  = "16KiB",  l1i_assoc = 8,
      l1d_size  = "16KiB",  l1d_assoc = 8,
      l2_size   = "128KiB", l2_assoc  = 8,
    )
  )
  ```
] <lst_final_gem5_conf>

