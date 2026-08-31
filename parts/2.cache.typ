= La cohérence de cache <cache_coherency>

== Qu'est-ce qu'un cache ?

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
  - exemple avec `struct list { int generation; int* data; }` (cf https://docs.kernel.org/kernel-hacking/false-sharing.html)

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
