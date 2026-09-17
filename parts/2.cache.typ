#import "/utils.typ": *

= La cohérence de cache <sec_cache_coherency>

== Qu'est-ce qu'un cache ? <sec_what_is_cache>

#set text(lang: "en")

Even though it is common to think of the processor and the memory as two very distinct component, they are much more interlinked than they may first appear. Beyond the fact that a processor with no data to process is not of much use, in a lot of workloads, memory speed constrains execution time just as much as processor speed; these tasks are called "memory-bound," as opposed to "CPU-bound" ones that are instead limited by the raw computing power of the CPU. For example, finding a specific value in a large list is almost always memory-bound: comparing a byte to another is a trivial task, but fetching the data to be compared is much trickier, and requires many back-and-forth between the processor and the memory. Just think of trying to find a needle in a haystack, except you can only compare one straw at a time, _and_ you can only compare it inside your house, _and_ the haystack is outside; that would be outrageously slow! A much smarter strategy would be to bring a handful of hay at a time and search in that, then go back to grab more hay from the haystack.

This idea, of fetching a large amount of data at once and then working on that instead of going back to the main source, is the basic insight behind caches: modern processors embed a small amount of very fast memory (between a few kilobytes and a few megabytes) that is managed by the CPU directly. Whenever they need to read from memory, they first check if they already have "cached" that data, and if not, they retrieve it from memory, storing it in the cache.

#let ft_line_size = [
  Modern consusmer processors can have cache lines of around 64 bytes @zen5_opt, with cache sizes varying from a few hundred kilobytes to a dozen megabytes. This means that a typical cache can have from a few thousand lines to hundreds of thousands, enough to hold a few compressed 4k pictures _just_ in one cache. That's a lot of handfuls of hay!
]

Much like with hay, it is only truly useful if you grab a handful of it at a time: when reading from main memory, the processor actually fetches _more_ bytes than what is actually needed, since memory acceses are often sequential (a property called "spatial locality"); this is, for example, the case when doing a linear search through an array. In our case, the "handful" of bytes fetched is called a _line_, and thus caches are arranged as sets of independant lines#footnote(ft_line_size) that are progressively filled by the processor. After some time, however, caches become full and there are no more free lines, and thus the cache has to discard the data contained in a line to make space for new data, a process known as "eviction".

#set text(lang: "fr")

#figure(
  todo[
    cpu/registers \<-\> cache \<-\> mémoire (\<-\> disque? on en a pas parlé donc bizarre a inclure mais bon)
  ],
  caption: [Représentation de la "hiérarchie de mémoire"]
) <fig_simple_mem_hier>

#set text(lang: "en")

Reading from this cache memory is typically around 200 times faster #todo[source?] than reading from main memory. Similarly, _writing_ to cache is also much faster, although there are differing techniques for dealing with it (known as "writing policies"), and, as we'll see later, they are the source of significant headaches. #todo[should we go in detail into write-through and write-back? (esp. cause we already talked about eviction, so write-back would make sense)]

#set text(lang: "fr")

Bien sûr, il y a un compromis fondamental entre la capacité de stockage du cache et sa vitesse, donc une évolution majeure des caches depuis leur naissance a été d'essayer d'augmenter leur taille sans affecter la vitesse, ce qui a résulté entre-autres, en l'idée d'avoir plusieurs "niveaux" de caches : le processeur a plusieurs banques de mémoires caches, allant progressivement de caches plus petits mais plus intégrés et proches du coeur, à des caches bien plus gros mais nécessairement plus éloignés et lents ; ces différents niveaux sont généralement notés L1 (cache très petit mais très proche), L2 (cache un peu plus grand mais plus éloigné), L3 (cache très grand mais très éloigné et relativement lent), etc.

#figure(
  todo[même diagramme mais cette fois-ci avec plusieurs niveaux de caches],
  caption: [Représentation de la "hiérarchie de mémoire" avec plusieurs niveaux de caches]
) <fig_multi_mem_hier>

== Multiples caches, multiples problèmes

Cependant, en parallèle de l'évolution des caches, les CPUs ont elles aussi énormément changées. Une des révolutions les plus impactantes a été l'apparition de plusieurs "coeurs" par processeur. Ces coeurs peuvent, indépendamment l'un de l'autre, exécuter des programmes différents ou même des parties distinctes d'un même programme.

#let ft_shared_l2 = [
  Comme discuté précédemment, les caches sont souvent divisés en différents niveaux, et il est donc commun d'avoir certains niveaux privés (e.g. L1 et L2) et d'autres partagés (e.g. L3). Cela introduit d'autres problèmes hors de notre sujet du jour.
]

Cette mitose a bien sûr demander de repenser une bonne partie des choix macro- et micro-architecturaux qui étaient jusqu'ici standards. Un des composants affectés par ce changement a été le cache : il faut maintenant faire un choix entre avoir un seul cache partagé entre tous les coeurs, ou assigner des caches séparés (ou "privés") à chaque coeur#footnote(ft_shared_l2).

Utiliser des caches partagés est généralement plus lent, étant donné que chaque opération sur le cache peut potentiellement demander de négocier pour s'assurer qu'il n'y a pas plusieurs coeurs qui tentent d'écrire au même endroit en même temps (ce qu'on appelle une _contention d'écriture_). À cela vient s'ajouter le compromis entre stockage et vitesse mentionné à la fin de la @sec_what_is_cache : si on rend la taille du cache proportionnelle au nombre de coeurs, alors on réduit sa vitesse d'accès pour tout le monde, alors que si on souhaite garder une vitesse attirante, il faudra réduire la taille du cache, et donc augmenter la _contention de stockage_ (plusieurs coeurs se battront pour obtenir assez de place pour mettre en cache les données dont ils ont besoin), ce qui est un problème pour les systèmes modernes où il est très commun exécuter plusieurs applications simultanément en répartissant leurs tâches sur différents coeurs. Étant donné ces compromis, cette architecture est de moins utilisée, et il n'est pas rare de voir des processeurs modernes où seul le dernier niveau de cache (i.e. L3 ou L4) est partagé.

Des caches privés évitent ces problèmes, en plaçant chaque coeur au contrôle d'une unité de cache, et en divisant une même quantité de stockage entre plusieurs caches, pour qu'ils soient individuellement plus rapides. Cependant, cette séparation amène un nouveau problème : maintenant qu'il n'y a plus d'unité centrale, il n'y a plus de _source de vérité_ partagée non plus. Ainsi, dans le cas où deux coeurs travaillent sur une même donnée en mémoire, si l'un d'entre eux la modifie, il n'y a désormais plus de garantie que l'autre coeur sera conscient de cette modification et utilisera la bonne "version" de la donnée. La @fig_incohenrency illustre un cas où deux coeurs traitent la même donnée (ici une variable `msg` stockée en mémoire), qui a été mise en cache dans leurs caches privés respectifs au préalable ; le coeur 1 tente de modifier ce message, ce qui change sa valeur dans son cache privé, mais cette mutation n'a pas été reproduite dans le cache du coeur 2, ce qui fait que, lorsque ce dernier lis la valeur de `msg`, son cache lui retourne une valeur maintenant obsolète.

#figure(
  image("/assets/incoherency_sketch.png", width: 70%),
  placement: auto,
  caption: [Un exemple d'incohérence entre deux caches privés]
) <fig_incohenrency>

// - exemple avec `struct list { int count; int* data; }` (cf https://docs.kernel.org/kernel-hacking/false-sharing.html)

== La communication, c'est important <sec_cache_protocols>

Il est donc essentiel de trouver un moyen de résoudre ce problème d'incohérence entre les deux caches. La solution évidente est de faire communiquer ces deux caches "privés", avec un _protocole de cohérence de cache_. Il existe une grande quantité de protocoles, selon les propriétés de cohérence requises, les performances attendues, ou même l'implémentation exacte de chaque cache.

- les protocoles de cohérence permettent de mitiger ça
  - petite explication textuelle abstraite
  - puis diagramme d'explication
  - "les lignes de cache peuvent être dans différents 'états' du point de vue du protocole"
    - cf. https://support.arm.com/documentation/102407/0102/CHI-protocol-fundamentals#md320-chi-protocol-fundamentals__chi-cache-line-states
    - et btw il existe un état spécifique pour une ligne de cache sur laquelle on écrit

Cependant, toutes ces communications ne sont pas gratuites.

- ...mais ils rajoutent:
  - de l'overhead pour les messages/allers-retours (cf [11] dans le rapport de johan)
  - des hypothèses/suppositions sur le comportement du code
    - (autant au design-time qu'au runtime)
    - exemple intéressant pour nous: Shared vs. Unique
- faire les bonnes hypothèses c'est essentiel pour de bonnes performances
  - si on désigne une ligne comme Shared au lieu de Unique on prend X% de temps en overhead
- sauf que la personne la mieux placée pour savoir ce que le code va faire, c'est celle qu'a _écrit_ le code
- l'idée de la thèse de johan c'est justement de permettre au programmeur de donner des indices au cache sur le comportement du code w.r.t. cohérence
