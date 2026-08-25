// #let todo(str) = box(fill: red, outset: .25em)[#str]
#let todo = highlight.with(fill: red)
#let laure = highlight.with(fill: purple)
#let footnotes(..its) = {
  its.pos().map(footnote).join(super(","))
}

#let zwj = "\u{200D}"

#let highlight-box(it, fill: auto, stroke: none, radius: 0pt) = box(
  fill: fill,
  stroke: stroke,
  inset: (x: .25em, y: 0pt),
  outset: (y: .25em),
  radius: radius,
  baseline: 2pt,
  box(baseline: -2pt, it)
)
