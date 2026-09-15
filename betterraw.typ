#let betteraw(
  label_re: regex("\\#<([[:alpha:]_0-9-]+)>"),
  supplement: "ligne",
  doc
) = {
  let transform_line = line => {
    let maybe_label = none
    let stripped_line = line

    // this is used a selector to hide comments when there's labels; however we only want to activate it in case there's a label, otherwise it'll just hide every comment. so in the meantime we just make it select something that's impossible inside a raw line: a raw block
    let maybe_comment = raw;

    let label_match = line.text.match(label_re);
    if label_match != none {
      let label_name = label_match.captures.at(0)
      maybe_label = label(label_name)

      maybe_comment = "//"

      // todo: check that this is actually a comment with just a ref instead of just matching on text
      // let body_parts = line.body.children;
      // let comment_idx = body_parts.position(
      //   part => {
      //     // if part != none and part.func() == styled {

      //     // }

      //     return false
      //   }
      // )
      // body_parts = body_parts.slice(0, comment_idx)

      // stripped_line = repr(body_parts)
    }

    show maybe_comment: it => []
    show label_re: it => []

    let lineno = line.number;

    // left-aligned line numbers
    let lineno_content = {
      let curr_lno_digit = calc.ceil(calc.log(lineno+1, base: 10));

      let max_lno = line.count;
      let max_lno_digit = calc.ceil(calc.log(max_lno+1, base: 10));

      let lno_digit_padding = max_lno_digit - curr_lno_digit;

      { (" " * lno_digit_padding) + str(line.number) }
    }

    [ #metadata((kind: "raw-line", lineno: lineno)) #maybe_label ]

    // use a box to make the grid in-line (which avoids having massive gaps between each line)
    box(
      grid(
        align: (top + right, top + left),
        columns: 2, column-gutter: 1em,

        lineno_content,
        line
      )
    )
  }

  show figure.where(kind: raw): it => {
    show raw.where(block: true): it => {
      show raw.line: transform_line
      it
    }

    it
  }

  show ref: it => context {
    let el = it.element;

    if el != none and el.func() == metadata and el.value.kind == "raw-line" {
      let label = it.target;
      let lineno = query(label).at(0).value.lineno;
      let sup = if it.supplement == auto { supplement } else { it.supplement }
      link(label)[#sup #lineno]
    } else {
      it
    }
  }

  doc
}
