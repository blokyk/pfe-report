#import "/utils.typ": *

= La cohérence de cache <sec_cache_coherency>

== Qu'est-ce qu'un cache ? <sec_what_is_cache>

Bien qu'on conçoive habituellement le processeur et la mémoire comme deux composants très distincts, ils sont en réalité plus intriqués qu'il n'apparaît. Au-delà du fait qu'un processeur sans données à traiter est d'une utilité limitée, dans beaucoup de tâches, la vitesse de la mémoire contraint le temps d'exécution tout autant que la vitesse du processeur ; ces tâches sont dites "bornées par la mémoire" (_memory-bound_), par opposition à celles bornées par la pure vitesse de calcul du processeur (_CPU-bound_). Par exemple, chercher une valeur spécifique dans un long tableau est une tâche presque toujours bornée par la mémoire : comparer deux octets est trivial, mais obtenir la donnée à comparer est bien plus subtil, et requiert de nombreux aller-retours entre le processeur et la mémoire. Pour illustrer, imaginez chercher une aiguille dans une botte de foin, sauf qu'on ne peut inspecter qu'un brin de paille à la fois, _et_ on ne peut l'inspecter qu'en étant à l'intérieur de la maison, _et_ la botte de foin est dehors ; ce serait terriblement lent ! Il serait bien plus stratégique d'amener une poignée de foin à chaque voyage, de l'inspecter, puis de retourner chercher du foin dehors.

Cette idée, de transporter une grande quantité de données d'un seul coup pour travailler dessus au lieu de faire des allers-retours incessants, est l'idée principale des caches. Les processeurs modernes sont équipés d'une petite quantité de mémoire très rapide qu'ils gèrent directement. À chaque accès mémoire, le processeur vérifie si la donnée est déjà présente dans le cache ; si non, il effectue un accès mémoire et stocke la donnée dans le cache.

#let ft_line_size = [
  Les processeurs modernes peuvent avoir des lignes d'environ 64 octets @zen5_opt, avec une taille totale variant de quelques centaines de kilo-octets à une dizaine de méga-octets. Un cache peut donc avoir entre quelques milliers et quelques centaines de milliers de lignes, assez pour stocker plusieurs images 4k rien que dans le cache. Ça en fait des poignées de foin !
]

Comme avec le foin, ce n'est utile que si on transporte plus qu'une petite quantité à chaque accès : lors d'une lecture en mémoire, le processeur requête en réalité _plus_ d'octets que nécessaires, profitant du fait que les accès mémoire sont souvent séquentiels (une propriété dite "localité spatiale", c'est par exemple le cas lors d'une recherche linéaire dans un tableau). Dans notre cas, la "poignée" de foin s'appelle une _ligne_, et le cache est organisé comme un ensemble de lignes indépendantes#footnote(ft_line_size) remplies à la demande par le processeur.

#let ft_size_tradeoff = [
  Entre autre, pour la raison simple que l'espace physiquement disponible à proximité du coeur du processeur est limité ; une autre raison est la technologie utilisé à l'intérieur de ces caches. Tragiquement, aucun de ces deux sujets ne sont ceux de ce rapport.
]

#figure(
  image("../assets/memory-hierarchy.svg", width: 85%),
  caption: [Représentation de la "hiérarchie de mémoire".],
  placement: none,
) <fig_simple_mem_hier>

#pagebreak()

Le cache implémente également un compromis taille/vitesse différent de la mémoire centrale. De façon générale, une mémoire peut être soit rapide d'accès pour le processeur, soit avoir une grande quantité de stockage, mais pas les deux#footnote(ft_size_tradeoff). Tous les points le long de ce spectre sont utiles, c'est pourquoi un ordinateur a, typiquement, à la fois des petites mémoires rapides, des grandes mémoires lentes, et des mémoires intermédiaires ; quelques ordres de grandeur sont donnés sur la @fig_simple_mem_hier. Le cache est typiquement capable d'atteindre la vitesse de la mémoire centrale avec une latence bien plus faible (par abus de langage, on dira même souvent qu'il est "plus rapide") ; en échange il est plus petit. Inévitablement au fur et à mesure de l'exécution, le cache se remplit donc jusqu'à ce qu'il n'y ait plus de lignes libres ; il doit alors défausser des lignes pour libérer de la place, un processus qu'on appelle _éviction_.

De la même façon, _écrire_ est aussi bien plus rapide dans le cache ; il y a toutefois des techniques plus variées (dites "politiques d'écriture") pour gérer les effets associés qui, comme on va le voir plus tard, sont la source de certains maux de tête. Par exemple, si l'on s'arrête initialement à une écriture dans le cache et qu'on ne la propage en mémoire que lors d'une éviction (politique _copy-back_), l'écriture est rapide mais la mémoire centrale ne contient pas la donnée réellement manipulée par le programme. D'un autre côté, si l'on pousse chaque écriture dans la mémoire centrale aussi pour synchroniser (politique _write-through_), le trafic mémoire augmente significativement et annule une partie des gains de performances liés au cache.

Le cache s'avère en pratique crucial pour les performances de programmes ; une évolution majeure depuis leur naissance a donc été d'essayer d'augmenter leur taille sans affecter la vitesse, ce qui a résulté entre-autres, en l'idée d'avoir plusieurs "niveaux" de caches : le processeur a plusieurs banques de mémoires caches, allant progressivement de caches plus petits mais plus intégrés et proches du coeur, à des caches bien plus gros mais nécessairement plus éloignés et lents ; ces différents niveaux sont généralement notés L1 (cache très petit mais très proche), L2 (cache un peu plus grand mais plus éloigné), L3 (cache très grand mais très éloigné et relativement lent), etc., illustrés sur la @fig_multi_mem_hier.

#figure(
  image("../assets/cache-hierarchy.svg"),
  caption: [Représentation d'une "hiérarchie de cache" typique à 3 niveaux.],
  placement: top
) <fig_multi_mem_hier>

== Multiples caches, multiples problèmes

Cependant, en parallèle de l'évolution des caches, les CPUs ont elles aussi énormément changé. Une des révolutions les plus impactantes a été l'apparition de plusieurs "coeurs" par processeur. Ces coeurs peuvent, indépendamment l'un de l'autre, exécuter des programmes différents ou même des parties distinctes d'un même programme.

#let ft_shared_l2 = [
  Comme discuté précédemment, les caches sont souvent divisés en différents niveaux, et il est donc commun d'avoir certains niveaux privés (e.g. L1 et L2) et d'autres partagés (e.g. L3), comme l'illustre la @fig_multi_mem_hier. Cela introduit d'autres problèmes hors de notre sujet du jour.
]

Cette mitose a bien sûr demandé de repenser une bonne partie des choix macro- et micro-architecturaux qui étaient jusqu'ici standards. Un des composants affectés par ce changement a été le cache : il faut maintenant faire un choix entre avoir un seul cache partagé entre tous les coeurs, ou assigner des caches séparés (ou "privés") à chaque coeur#footnote(ft_shared_l2).

Utiliser des *caches partagés* est généralement plus lent, étant donné que chaque opération sur le cache peut potentiellement demander de négocier pour s'assurer qu'il n'y a pas plusieurs coeurs qui tentent d'écrire au même endroit en même temps (ce qu'on appelle une _contention d'écriture_). À cela vient s'ajouter le compromis entre stockage et vitesse mentionné à la fin de la @sec_what_is_cache : si on rend la taille du cache proportionnelle au nombre de coeurs, alors on réduit sa vitesse d'accès pour tout le monde, alors que si on souhaite garder une vitesse attirante, il faudra réduire la taille du cache, et donc augmenter la _contention de stockage_ (plusieurs coeurs se battront pour obtenir assez de place pour mettre en cache les données dont ils ont besoin), ce qui est un problème pour les systèmes modernes, où il est très commun d'exécuter plusieurs applications simultanément en répartissant leurs tâches sur différents coeurs. Étant donnés ces compromis, cette architecture est de moins en moins utilisée, et il n'est pas rare de voir des processeurs modernes où seul le dernier niveau de cache (i.e. L3 ou L4) est partagé.

Des *caches privés* évitent ces problèmes, en plaçant chaque coeur au contrôle d'une unité de cache, et en divisant une même quantité de stockage entre plusieurs caches, pour qu'ils soient individuellement plus rapides. Cependant, cette séparation amène un nouveau problème : maintenant qu'il n'y a plus d'unité centrale, il n'y a plus de _source de vérité_ partagée non plus. Ainsi, dans le cas où deux coeurs travaillent sur une même donnée en mémoire, si l'un d'entre eux la modifie, il n'y a désormais plus de garantie que l'autre coeur sera conscient de cette modification et utilisera la bonne "version" de la donnée. La @fig_incohenrency illustre un cas où deux coeurs traitent la même donnée (ici une variable `msg` stockée en mémoire), qui a été mise en cache dans leurs caches privés respectifs au préalable ; le coeur 1 tente de modifier ce message, ce qui change sa valeur dans son cache privé, mais cette mutation n'a pas été reproduite dans le cache du coeur 2, ce qui fait que, lorsque ce dernier lit la valeur de `msg`, son cache lui retourne une valeur maintenant obsolète.

#figure(
  image("/assets/incoherency.svg", width: 75%),
  caption: [Un exemple d'incohérence entre deux caches *privés*.],
) <fig_incohenrency>

// - exemple avec `struct list { int count; int* data; }` (cf https://docs.kernel.org/kernel-hacking/false-sharing.html)

== La communication, c'est important <sec_cache_protocols>

Il est donc essentiel de trouver un moyen de résoudre ce problème d'incohérence entre les deux caches. La solution évidente est de faire communiquer ces deux caches "privés", avec un _protocole de cohérence de cache_. Il existe une grande quantité de protocoles, selon les propriétés de cohérence requises, les performances attendues, ou même l'implémentation exacte de chaque cache, mais globalement les protocoles s'assurent que :
  - Les écritures dans un cache sont visibles par tous les caches, immédiatement ou à la demande
  - Les accès à une même donnée en mémoire s'exécutent comme s'ils étaient séquentiels

Dans le contexte de la thèse de Johan en général, et donc de ce stage en particulier, on suppose un protocole "par répertoire" dans lequel un répertoire central traque quels caches ont des copies de quelles lignes, si les lignes ont été modifiées, et d'autres propriétés nécessaires ; ces informations nous permettent alors de déclencher les transferts entre-cache dès que nécessaire. Concrètement, chaque ligne a un "état" (accès exclusif et ligne non modifiée, accès exclusif et ligne modifiée, accès partagé...) et chaque accès mémoire par un coeur dans le système provoque des transitions d'état potentiellement accompagnées de propagation des modifications d'un cache aux autres.

Ce travail de cohérence a un coût non négligeable sur la bande passante des bus concernés, surtout pour les processeurs ayant beaucoup de coeurs tous affairés à la même tâche répartie en parallèle. Une des raisons de ce coût est que le système de cache ne connaît pas à l'avance quels accès le programme va effectuer, et doit donc répliquer les données pour répondre à tous les scénarios possibles. Habituellement, un cache demande une ligne en mode _partagée_, ce qui lui donne le "droit" de la lire mais non pas de la modifier ; pour pouvoir écrire à cet emplacement, il devra demander l'accès _exclusif_ à cette ligne, qui lui permet à la fois de lire et écrire dessus, mais requiert que cette ligne soit alors retransmise aux autres caches par la suite.

// - ...mais ils rajoutent:
//   - de l'overhead pour les messages/allers-retours (cf [11] dans le rapport de johan)
//   - des hypothèses/suppositions sur le comportement du code
//     - (autant au design-time qu'au runtime)
//     - exemple intéressant pour nous: Shared vs. Unique
// - faire les bonnes hypothèses c'est essentiel pour de bonnes performances
//   - si on désigne une ligne comme Shared au lieu de Unique on prend X% de temps en overhead

Cependant, si un coeur pouvait, en théorie, savoir au moment de la lecture d'une ligne qu'il va plus tard écrire dessus, il devrait être possible de demander la ligne en mode exclusif immédiatement, sans avoir besoin de faire une demande inutile de mode partagé. L'idée centrale de la thèse de Johan est de fournir logiciellement cette information sur le comportement des programmes au système de cache. Le logiciel, à travers sa conceptrice ou, comme on va le voir, son compilateur, peut être annoté d'indices micro-architecturaux annonçant à l'avance les intentions du code et permettant au protocole de cohérence de cache de planifier efficacement les copies et invalidations de lignes dans les caches privés.
