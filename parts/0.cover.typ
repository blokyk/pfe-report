#set scale(reflow: true)

#set heading(outlined: false)

#show heading: set text(18pt)
#show heading: strong

#page(
  margin: 1cm
)[
  #align(left, scale(7.5%, image("/assets/esisar.png")))

  #show: align.with(center + horizon)

  = #upper[Rapport de projet de fin d'études]

  = #upper[Grenoble INP] -- Esisar, UGA 2025/2026

  #v(4em)

  = Support de nouvelles instructions RISC-V dans le \ compilateur LLVM et le simulateur gem5

  #v(4em)

  #grid(
    rows: 2,
    row-gutter: 1em,
    scale(13%, image("/assets/tima.png")),
    [
      Laboratoire TIMA \
      46 Avenue Félix Viallet \
      38031 Grenoble, Cedex 1
    ],
  )

  #v(4em)

  *Zoë Courvoisier-Clément*

  #v(4em)

  #table(
    columns: 2,
    align: center + horizon,
    inset: 1em,
    [ *Dates du stage* ], [ 31/03/2026 -- 11/09/2026 ],
    [ *Spécialité* ], [ Informatique, Réseaux, et Cybersécurité ],
    [ *Maître·sse·s de stage* ], [ Julie DUMAS \ Arthur PERAIS ],
    [ *Tuteur ESISAR* ], [ Amir-pasha MIRBAHA ]
  )
]
