#import "/utils.typ": *

#set heading(numbering: none)

#set scale(reflow: true)

#set heading(outlined: false)

#show heading: set text(18pt)
#show heading: strong

#page[
  #align(left, scale(7.5%, image("/assets/esisar.png")))
  #v(1em)

  #align(center)[
    = #upper[Rapport de projet de fin d'études]

    = #upper[Grenoble INP] -- Esisar, UGA 2025/2026
  ]
  #v(2em)

  *Mots-clés* : Cohérence de cache, Compilation, Simulation, Co-conception logiciel/matériel

  #rect(width: 100%, inset: 8pt)[
    *Résumé* : Les systèmes de cohérence de cache sont un composant essentiel des machines multicoeurs, qui permettent à chaque coeur de manipuler des caches privés rapides sans perdre la cohérence globale des informations vues par les autres coeurs. Ils imposent cependant un coût, invisible par le programme, en communications internes de synchronisation. Une optimisation prometteuse pour ce mécanisme est d'adapter le comportement du cache à la tâche en se basant sur des informations prévisionnelles fournies par le programme. Par exemple, un programme qui lit une ligne de cache en sachant qu'il va y écrire peut obtenir en avance un accès exclusif et réduire le volume de travail pour le protocole de cohérence. Nous explorons une implémentation en co-conception logiciel/matériel de cette idée, où le compilateur LLVM annote par une optimisation les lectures susceptibles de mener à une écriture subséquente, dont nous évaluons les performances dans le simulateur de processeur gem5. Sur un programme d'exemple représentatif, cette optimisation réduit le temps d'exécution de 1.48% et le volume de messages de cohérence de 10.2%. Notre preuve de concept valide l'intuition théorique et notre implémentation packagée facilite les futures expériences prévues autour de ce sujet.
  ]

  *Keywords*: Cache coherence, Compilation, Simulation, Software/Hardware co-design

  #rect(width: 100%, inset: 8pt)[
    *Abstract*: Cache coherence protocols are a key component of multicore processors, allowing each core to leverage fast private caches without compromising the global consistency of the data seen by other cores. These protocols, however, carry an invisible cost for the program, in terms of internal synchronization overhead. A promising optimization for this mechanism is to tailor the cache's behavior to the workload, by exploiting memory pattern hints provided by the program. For instance, a program that reads a cache line knowing it will soon write to it can request exclusive access to the line early, and thus reduce the amount of work for the cache coherence protocol. We explore a software/hardware-co-designed implementation of this idea, where the LLVM compiler annotates, through an optimization, memory read instructions that are likely to lead to a subsequent write; we then evaluate the performance gains in the gem5 processor simulator. On a simple representative benchmark, this optimization reduces execution time by 1.48% and the volume of coherence protocol messages by 10.2%. Our proof of concept validates the theoretical intuition and our packaged implementation provides a good basis for further experiments planned in this line of work.
  ]
]
