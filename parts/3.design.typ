#import "/utils.typ": *

= Conception <sec_design>

== #todo[Entrées de dev]

- faire un "gradient" comparatif entre tout annoter manuellement et laisser le compilateur inférer
  - donner un autre exemple d'inférence que fait le compilo (ex. )
- en plus, il y a souvent des loads "cachés" que l'utilisateur ne contrôle pas forcément
- c'est une optimisation plutôt locale donc plus facile pour le compilo à détecter

== Forme finale du code

// - this isn't even my final form! (has to go through pseudo-isel first)

note: je sais pas si c'est vraiment une bonne idée de mettre ça ici, vu que c'est un peu trop loin de la partie sur le cache du coup, mais le mettre ici aide à la narrativisation de l'écrit

- le compiler est sûr qu'un load va bientôt écrire au même endroit
- plusieurs choix:
  - une instruction spéciale (hint) _avant_ un load
    - (c'est pas vraiment une "instr" dans le sens asm, mais quasiment)
  - un load spécial (enfin, un par taille+signe de donnée)
- au final un load spécial est plus facile à implémenter côté hardware

== la compil

- pipeline/schéma traditionnel de compil
- zoom sur la partie middle-end/optimisation
- on a du code assez haut niveau qui rentre, avec beaucoup de truc inefficaces mais aussi pas mal d'indices de ce que voulait faire l'auteur
- puis on a différente étapes, soit d'opti soit de lowering, jusqu'à ce qu'on sorte du quasi-code-machine
  - il y a des informations qui sont à certaines étapes, et il y a aussi des informations qu'on ne connaît pas forcément encore

- en pratique (\<5mois, je connais rien à llvm), on fait juste une version très naïve de la strat automatique

== plan pour l'opti

- étant donné point précédent, justifier le choix d'où on va se placer exactement dans la pipeline d'opti
- on va scanner tous les loads pour voir s'il y a des stores aux mêmes endroits
- ...mais comment est-ce qu'on sait ça?
  - (maybe mentionner les trucs qui ne marcheraient pas justement)
  - alias analysis
    - être assez bref
    - mentionner que c'est pas exact et qu'il y a pas mal de trade-offs (on peut pas encore citer le AADB mais on peut citer e.g. SVF)
    - c'est aussi assez dur à compute
- étant donné qu'AA est dur et pas précis, cette approche est très naïve, mais c'est un PoC

== maintenant, on passe le relai au hardware <sec_design_hw>

- ...en pratique, on utilise un simulateur parce que beaucoup plus facile que le hardware
  - on aurait pu utiliser un truc genre verilator mais à peu près aussi galère que du vrai hardware
- le simulateur doit pouvoir décoder l'instr
- ET il doit ordonner au cache de se comporter correctement
