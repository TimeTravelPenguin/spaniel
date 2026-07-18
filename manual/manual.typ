#import "@preview/tidy:0.4.3"

#set document(title: "Spaniel API Reference", author: "TimeTravelPenguin")
#set page(numbering: "1", margin: (x: 2.2cm, y: 2.4cm))
#set text(size: 10.5pt)
#set par(justify: true)
// Number chapters and module sections only; leave the deeper function and
// parameter headings that tidy emits unnumbered.
#set heading(numbering: (..n) => if n.pos().len() <= 2 {
  numbering("1.1", ..n)
})
#show link: set text(blue.darken(20%))

#let VERSION = version(
  sys.inputs.at("version").split(".").map(int),
)


// -----------------------------------------------------------------------------
// Example scope
//
// The `example` blocks in the doc-comments are executed by tidy and rendered
// with their output. They run against this scope: the whole package API (public
// and internal) plus a handful of reusable fixtures modelling a tiny "scalars
// and vectors" algebra, mirroring the package's own usage example.
// -----------------------------------------------------------------------------

#import "examples-scope.typ": example-scope

// Parse a source module by its file name (relative to the project root).
#let parse-src(name) = tidy.parse-module(
  read("/src/" + name + ".typ"),
  name: name,
  scope: example-scope,
)

// Render a parsed module: an optional description followed by its definitions.
#let render-module(module, private: false) = {
  let keep = def => not private or def.name.starts-with("_")
  let functions = module.functions.filter(keep)
  let variables = module.variables.filter(keep)

  // Show the module description in the public pass, and in the internal pass
  // only for modules that are entirely private (so it is not repeated).
  let all-private = (module.functions + module.variables).all(def => (
    def.name.starts-with("_")
  ))
  let show-description = not private or all-private

  if (
    show-description
      and module.description != none
      and module.description.trim() != ""
  ) {
    eval(module.description.trim(), mode: "markup", scope: example-scope)
    parbreak()
  }

  tidy.show-module(
    (..module, functions: functions, variables: variables),
    first-heading-level: 2,
    show-module-name: false,
    show-outline: false,
    omit-private-definitions: not private,
  )
}

// Public API modules, in reading order, paired with their chapter titles.
#let public-modules = (
  ("types", "Types"),
  ("runtime", "Runtime objects"),
  ("operations", "Operations & implementations"),
  ("registry", "Extensions & worlds"),
  ("dispatch", "Dispatch"),
  ("types/builtin", "Builtin types"),
)

// Every module that contains internal (underscore-prefixed) definitions.
#let internal-modules = (
  ("internal", "Results"),
  ("types", "Type internals"),
  ("matching", "Pattern matching & specificity"),
  ("registry", "Registry internals"),
  ("dispatch", "Dispatch internals"),
  ("types/builtin", "Builtin type internals"),
)


// -----------------------------------------------------------------------------
// Title
// -----------------------------------------------------------------------------

#align(center)[
  #text(size: 2.4em, weight: "bold")[Spaniel]

  #v(0.2em)
  #text(size: 1.1em)[Pseudo-objects and interfaces in Typst]

  #v(0.4em)
  API reference · version #VERSION
]

#v(1em)

#outline(depth: 2, indent: auto)

#pagebreak(weak: true)

= Preface

Please note that this document contains examples that include undocumented functions and
variables. These exist only to support the examples and are not part of the public API.
They are defined @example-scope, which describes the scope used when evaluating the examples.

In brief, these terms are as follows: `vector`, `Mul`, `mul_int_int`, `S`, `T`, `U`,
`mul_scalar_vector`, `algebra`, `world`, and `mul`. Examples otherwise use the natively
documented `Int` type and the `Array[_]` constructor (`array_of`) from the builtin types.

// -----------------------------------------------------------------------------
// Public API
// -----------------------------------------------------------------------------

= Public API

#for (name, title) in public-modules {
  heading(title, level: 2)
  render-module(parse-src(name))
}


// -----------------------------------------------------------------------------
// Internal API
// -----------------------------------------------------------------------------

#pagebreak(weak: true)

= Internal API

The definitions below are private, underscore-prefixed helpers. They are *not*
part of the public API and may change without notice; they are documented here
for contributors working on the package internals.

#for (name, title) in internal-modules {
  heading(title, level: 2)
  render-module(parse-src(name), private: true)
}

// -----------------------------------------------------------------------------
// Appendix: Example scope
// -----------------------------------------------------------------------------

#pagebreak(weak: true)
= Appendix

== Example scope <example-scope>

#{
  import "@preview/codly:1.3.0": *
  show: codly-init.with()

  let example-scope-src = read("examples-scope.typ")

  codly(zebra-fill: none, display-icon: false, display-name: false)
  raw(
    example-scope-src.split("\n").slice(0, -2).join("\n"),
    lang: "typ",
    block: true,
  )
}
