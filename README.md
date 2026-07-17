<p align="center">
  <img src="https://raw.githubusercontent.com/TimeTravelPenguin/spaniel/refs/heads/main/assets/spaniel.png" alt="project logo" width="300">
</p>

<h1 align="center">Spaniel</h1>

<p align="center">
  <em>Pseudo-objects and interfaces in Typst — nominal types, contracts, and multiple dispatch.</em>
</p>

Spaniel lets Typst library authors define **typed objects that obey contracts** and
**operations that dispatch on the runtime types of their arguments**. Together these give
you the interfaces, ad-hoc polymorphism, and _open_ extensibility that Typst's scripting
layer does not provide on its own — enforced at the API level rather than by convention.

> [!IMPORTANT]
> Please note that this package is a work in progress. It takes time to fully scope out
> feature requirements, test designs, review, and build up something I am happy with.

## Why?

While Typst is incredibly powerful on its own, it is dynamically typed and does not
(currently) allow user-defined types. This means there no method dispatch, and especially
no interfaces or traits. For a document, that is rarely a problem. For an _advanced
library_ — a computer-algebra system, a units package, a plotting toolkit — it creates
real friction.

Most of the time, complex packages can be implemented using WASM and a more expressive
programming language. However, when your package requires using aspects of the Typst
language itself, it can be very difficult or impossible to do this.

### Problem 1 — everything is a `dictionary`

The idiomatic way to model a value is a tagged dictionary:

```typ
#let complex(re, im) = (tag: "complex", re: re, im: im)
#let vector(xs) = (tag: "vector", xs: xs)
```

But Typst has no notion that these are _different kinds of things_. They share one type,
and nothing distinguishes a real object from any dictionary that happens to have the right
shape:

```typ
#assert.eq(type(complex(1, 2)), type(vector((1, 2))))  // true — both are `dictionary`
```

Nothing stops a caller from passing a malformed value, either. A missing or wrongly-typed
field is not caught where the object is built; it surfaces much later, deep inside your
code, as a confusing error far from its cause.

### Problem 2 — you cannot dispatch, and you cannot be extended

Suppose you want a single `mul` to work across several combinations of operands. In plain
Typst you end up hand-writing a ladder that inspects tags:

```typ
#let mul(a, b) = {
  if a.tag == "int" and b.tag == "int" { .. }
  else if a.tag == "int" and b.tag == "vector" { .. }
  else if a.tag == "matrix" and b.tag == "vector" { .. }
  else { panic("mul: unsupported operands") }
}
```

This is verbose, easy to get subtly wrong, and — most importantly — **closed**. A
downstream package that introduces a `Quaternion` type cannot teach _your_ `mul` about it
without forking your source. There is no way to pick the _most specific_ case among
overlapping ones, and no way to say "this case applies _provided_ some other operation
also exists" (the essence of a generic implementation).

## How Spaniel helps

Spaniel provides five ingredients that together deliver contracts and multiple dispatch:

| Concept                                | Function(s)                              | Replaces                    |
| -------------------------------------- | ---------------------------------------- | --------------------------- |
| **Runtime types** with validators      | `nominal_type`, `type_constructor`       | tag strings + manual checks |
| **Objects** boxed with their type      | `object`                                 | bare dictionaries           |
| **Operations** — named dispatch points | `operation`                              | a plain function name       |
| **Implementations** per type-signature | `implementation`, `requires`             | `if`/`else` ladders         |
| **Worlds** — validated registries      | `extension`, `build_world`, `dispatcher` | one closed function         |

- Types carry a **validator**, so `object(..)` rejects a malformed payload _at
  construction_ with a clear message — the contract is enforced at the boundary (Problem 1).
- Implementations are matched by the **runtime types** of the arguments, and the **most
  specific** one is selected; genuine ambiguities are reported rather than resolved
  silently (Problem 2).
- Implementations may be **generic** — using type variables such as `T` — and may declare
  **requirements** with `requires`, e.g. _"I can scale a vector of `T`, provided I can
  scale a single `T`"_. The requirement is resolved recursively during dispatch.
- A **world** is assembled from one or more **extensions**, so _different packages_ can
  each contribute operations and implementations that compose. Dispatch is **open**: a new
  type ships its own implementations instead of editing yours (Problem 2).

## A minimal example

```typ
// 1. Runtime types with contracts — validated whenever you build a value.
#let Num = nominal_type(
  "demo/Num",                       // "demo/Num" is the types' namespace.
  name: "Num",                      // You can replace "demo" with your project name.
  validate: v => type(v) == int,
)
#let Vec = nominal_type(
  "demo/Vec",
  name: "Vec",
  validate: v => (
    type(v) == array and v.all(x => type(x) == int)
  ),
)

#let num(n) = object(Num, n)
#let vec(xs) = object(Vec, xs)

// 2. One dispatch point...
#let Scale = operation("demo/Scale", 2, name: "scale")

// 3. ...with two implementations, chosen by argument type.
#let scale-num = implementation(
  Scale,
  (Num, Num),
  Num,
  (ctx, a, b) => num(a.value * b.value),
)
#let scale-vec = implementation(
  Scale,
  (Num, Vec),
  Vec,
  (ctx, k, xs) => vec(xs.value.map(x => x * k.value)),
)

// 4. Combine everything into an immutable, validated world.
#let world = build_world(extension(
  operations: (Scale,),
  implementations: (scale-num, scale-vec),
))
#let scale = dispatcher(world, Scale)

// 5. One name, resolved to the right implementation by argument type:
#scale(num(6), num(7)).value          // 42
#scale(num(3), vec((1, 2, 3))).value  // (3, 6, 9)
```

`build_world` validates the entire registry up front — arities, duplicate implementations,
references to undeclared operations, and unbound type variables — so configuration
mistakes are caught once, not on every call.

## Generics: one implementation, many types

The real payoff is _generic_ implementations. Instead of a separate case for every element
type, you write **one** implementation over **type variables** and constrain it with
`requires`.

Below, `Vector` is a parametric type built with `type_constructor`, and a single generic
implementation multiplies a scalar `S` by a `Vector[T]` — _provided_ the world can already
multiply `S` by `T` (yielding some `U`). That requirement is resolved recursively during
dispatch, and `U` — discovered from the required operation's output — becomes the element
type of the result.

```typ
// A scalar type, and a parametric `Vector[T]` whose contract is recursive:
// every element must itself be a valid `T`.
#let Int = nominal_type(
  "demo/Int",
  name: "Int",
  validate: v => type(v) == int,
)
#let integer = v => object(Int, v)

#let Vector = type_constructor(
  "demo/Vector",
  1,
  name: "Vector",
  validate: (args, v) => (
    type(v) == array and v.all(x => payload_valid(args.first(), x))
  ),
)
#let vector-of = t => apply_type(Vector, t)
#let vec = (t, xs) => object(vector-of(t), xs)

#let Mul = operation("demo/Mul", 2, name: "mul")

// The concrete base case: Int × Int -> Int.
#let mul-int = implementation(
  Mul,
  (Int, Int),
  Int,
  (ctx, a, b) => int(a.value * b.value),
)

// Type variables for the generic case.
#let S = type_variable("S")
#let T = type_variable("T")
#let U = type_variable("U")

// The generic case: S × Vector[T] -> Vector[U], provided S × T -> U exists.
#let mul-scalar-vec = implementation(
  Mul,
  (S, vector-of(T)),
  vector-of(U),
  (ctx, k, xs) => vec(
    // `ctx.bindings` holds T and U, resolved for this call; `ctx.dispatch`
    // re-enters the world to satisfy the requirement element-by-element.
    ctx.bindings.at("U"),
    xs.value.map(x => {
      let dispatch = ctx.dispatch
      let obj = object(ctx.bindings.at("T"), x)
      dispatch(Mul, k, obj).value
    }),
  ),
  constraints: (requires(Mul, (S, T), output: U),),
)

#let world = build_world(extension(
  operations: (Mul,),
  implementations: (mul-int, mul-scalar-vec),
))
#let mul = dispatcher(world, Mul)

#mul(integer(6), integer(7)).value           // 42          — base case
#mul(integer(2), vec(Int, (1, 2, 3))).value  // (2, 4, 6)   — generic case
```

The generic implementation never mentions `Int`. Add a new scalar type with its own `Mul`
implementation and `mul` scales vectors of it too — with no change to `mul-scalar-vec`.
Because dispatch is open, that new type and its implementation can even live in a
_different_ package.

## Documentation

The full API — including generic implementations, requirement constraints, and the
internal architecture — lives in **[the manual](manual/manual.pdf)**, generated with
[tidy](https://github.com/Mc-Zen/tidy) from the doc-comments in `src/`.

## Installation

Spaniel is currently in development. Once `v0.1.0` is reached, it will be published to the
Typst Universe. Until then you must manually install the package.

Once you have cloned the repository, you can use `just` to bundle the package:

```bash
just bundle
```

If you are on macOS, you can use `just install-dist` to automatically copy the bundle to
your `@local` typst packages. On all other platforms, you must copy it there manually.

## Acknowledgment of AI Usage

During development, AI _was_ used and _heavily_ scrutinised. My usage and strategy was as
follows:

1. Write a complete basic implementation _without the help of AI_.
2. Begin inquiring AI for small aspects of the project, building up to the full scope.
   Once the AI has fully grasped the concept of the project, inquire for suggested
   concepts and resources to research.
3. Begin showing small code implementations to AI not at review, but as a way to verify
   both its understanding and capabilities, as well as to have any issues pointed out
   early.
4. With the AI, construct a list of implementation requirements. At this point, pseudocode
   is introduced to explore API and concepts in depth.
5. Begin a full review of the codebase. With its understanding, it is able to review and
   get a more rounded understanding of the project goals and expected outcomes. This is a
   good point to introduce examples to hone in on an end-goal.
6. Begin refactor. In this case, almost everything was touched up in some way, whether
   because assertions were moved to their own functions, because the implementation was
   poor, or because the approach was incomplete or incorrect and AI had provided a fuller
   outcome. This last point occurred when the AI showed that it was possible to design the
   library to allow for a form of type variables and type constraints within
   `implementation` definitions. Originally, this was not a planned feature.
7. Add docstrings as working, and use AI at a later point to clean them up. AI was also
   used to put together the user manual (mostly), and also to expand the examples of this
   readme.

## About the name

Spaniel is named after my dog's breed - a Cocker Spaniel. She doesn't like it when I am at
my computer, much like how Typst dislikes static types. Neither of us are allowed to type.

## License

Spaniel's source code is distributed under the [MIT License](LICENSE).

## Additional Credits

Logo was illustrated by `@engmoustly` ([insta]) ([fiverr])

[insta]: https://www.instagram.com/engmoustly
[fiverr]: https://www.fiverr.com/engmoustly
