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
    *Résumé* : #todo(lorem(200))
  ]

  *Keywords*: Cache coherence, Compilation, Simulation, Software/Hardware co-design

  #rect(width: 100%, inset: 8pt)[
    *Abstract*: #todo(lorem(200))
  ]
]
