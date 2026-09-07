#import "/utils.typ": *

= La cohérence de cache <sec_cache_coherency>

== Qu'est-ce qu'un cache ?

#set text(lang: "en")

Even though it is common to think of the processor and the memory as two very distinct component, they are much more interlinked than they may first appear. Beyond the fact that a processor with no data to process is not of much use, in a lot of workloads, memory speed constrains execution time just as much as processor speed; these tasks are called "memory-bound," as opposed to "CPU-bound" ones that are instead limited by the raw computing power of the CPU. For example, finding a specific value in a large list is almost always memory-bound: comparing a byte to another is a trivial task, but fetching the data to be compared is much trickier, and requires many back-and-forth between the processor and the memory. Just think of trying to find a needle in a haystack, except you can only compare one straw at a time, _and_ you can only compare it inside your house, _and_ the haystack is outside; that would be outrageously slow! A much smarter strategy would be to bring a handful of hay at a time and search in that, then go back to grab more hay from the haystack.

This idea, of fetching a large amount of data at once and then working on that instead of going back to the main source, is the basic insight behind caches: modern CPUs embed a small amount of very fast memory (between a few kilobytes and a few megabytes) that is managed by the processor directly. Reading from this cache memory is typically around 200 times faster #todo[source?] than reading from main memory. However,

- une bonne partie des opérations d'un programme moyen sont des accès à la mémoire
- sauf que la mémoire ram c'est lent
- donc on a besoin d'un cache, qui est une petite mémoire à côté du cpu qu'est beaucoup plus rapide (+ comparer temps d'accès relatif (i.e. "10x plus rapide" plutôt que "$x$ cycles vs $y$ cycles"))

== Multiples caches, multiples problèmes

- les processeurs modernes ont plusieurs coeurs qui font des trucs disjoints
- si on a juste un gros cache partagé, alors c'est plus lent et moins efficace
  - il faut locker les lignes
  - chaque coeurs a moins de place (ce qui est un problème quand ils ne font pas la même chose, ce qui est souvent le cas)
- sauf que, si on essaie d'avoir des caches individuels, maintenant on a des problèmes quand on écrit
  - [petit diagramme pour expliquer]
  - exemple avec `struct list { int count; int* data; }` (cf https://docs.kernel.org/kernel-hacking/false-sharing.html)

== La communication, c'est important

- les protocoles de cohérence permettent de mitiger ça
  - petite explication textuelle abstraite
  - puis diagramme d'explication
- ...mais ils rajoutent:
  - du overhead pour les messages/allers-retours (cf [11] dans le rapport de johan)
  - des hypothèses/suppositions sur le comportement du code
    - (autant au design-time qu'au runtime)
    - exemple intéressant pour nous: Shared vs. Unique
- faire les bonnes hypothèses c'est essentiel pour de bonnes performances
  - si on désigne une ligne comme Shared au lieu de Unique on prend X% de temps en overhead
- sauf que la personne la mieux placée pour savoir ce que le code va faire, c'est celle qu'a _écrit_ le code
- l'idée de la thèse de johan c'est justement de permettre au programmeur de donner des indices au cache sur le comportement du code w.r.t. cohérence
