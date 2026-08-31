#set text(lang: "fr", font: "Libertinus Sans")

#import "/betterraw.typ": betteraw
#import "/prelude.typ": prelude

#show: betteraw
#show: prelude

#include "parts/0.cover.typ"

#outline(indent: auto)

#pagebreak()

// add a page number in the footer, and start page counter from here
#set page(
  header: context [
    // reset the footnote numbers every page
    #counter(footnote).update(0)
  ],
  footer: context [
    Zoë Courvoisier-Clément
    #h(1fr)
    #counter(page).display(
      "1"
    )
  ]
)

// // avoid counting the cover page
// #counter(page).update(1)

// every heading from this point on should be outlined
#set heading(outlined: true, numbering: "1.1.")

#include "parts/1.intro.typ"
#include "parts/2.cache.typ"
#include "parts/3.design.typ"
#include "parts/4.llvm.typ"
#include "parts/5.gem5.typ"
#include "parts/6.planning.typ"
#include "parts/7.results.typ"
#include "parts/8.conclusion.typ"

#pagebreak(weak: true)
#bibliography("works.bib", style: "ieee")
#pagebreak()

#set heading(numbering: "A.1.")
#counter(heading).update(0)

#set page(
  numbering: "i",
  footer: context [
    Zoë Courvoisier-Clément
    #h(1fr)
    #counter(page).display(
      "i"
    )
  ]
)
#counter(page).update(1)

#pagebreak(weak: true)
#include "parts/a.summary.typ"
#pagebreak()

#include "parts/b.annex.typ"
