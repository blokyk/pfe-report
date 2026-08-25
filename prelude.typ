#let prelude(doc) = {
  import "/utils.typ": highlight-box

  set page("a4", margin: 2cm)
  set par(justify: true)
  set par(spacing: 1.5em)
  set text(
    size: 12pt,
    font: "Libertinus Sans",
    lang: "fr",
  )

  // headings should be serif
  show heading.where(outlined: true): set text(font: "Libertinus Serif")

  set enum(indent: 1em)
  set scale(reflow: true) // by default, layout with scaled size, not original one
  set cite(style: "alphanumeric")

  // by default, write refs' text in lowercase (e.g. 'le chapitre 1' vs
  // 'le Chapitre 1')
  show ref.where(supplement: auto): it => {
    // we can't just #show: lower, because then the numbering of the ref is also lower, which isn't ok for "A.III." type numberings
    // we can't just #set ref(supplement: ...) either because code line refs are hacky and break if we do that
    let el = it.element;
    if el == none or not el.has("supplement") { return it; }

    show el.supplement.text: lower
    it
  }
  // ... EXCEPT biblio refs, which are distinguishable by
  // their lack of element (and because of typst show-rule scoping, the
  // least specific selector should have the innermost rule)
  //show ref.where(element: none): upper

  // Global show rules for links:
  //  - Show links to websites in blue
  //  - Underline links to websites
  //  - Show other links as-is
  show link: it => if type(it.dest) == str {
    set text(fill: blue)
    underline(it)
  } else {
    it
  }

  show raw: set text(font: "DejaVu Sans Mono", size: 9pt)
  // Display inline raw text in gray boxes, like markdown
  show raw.where(block: false): highlight-box.with(fill: luma(235), radius: 2pt)

  // Display raw blocks with a border
  show raw.where(block: true): block.with(
    stroke: 1pt + luma(235),
    inset: (x: .75em, y: .75em),
    radius: .32em
  )

  // write top-level sections in bold and add a bit of spacing
  show outline.entry.where(
    level: 1
  ): it => {
    v(12pt, weak: true)
    set text(font: "Libertinus Sans")
    strong(it)
  }

  show figure.where(kind: raw): set figure(supplement: "Listing")
  show figure.where(kind: "algo"): set figure(supplement: "Algorithme")
  show figure.caption: set par(justify: false)
  // show figure.caption: box.with(width: 80%)

  show "oe": "\u{0153}"

  set heading(supplement: "Section")

  doc
}
