#import "../src/types/builtin.typ": *
#import "../src/lib.typ": *

// -----------------------------------------------------------------------------
// `ToString` — the analogue of Rust's `ToString` trait.
//
//   trait ToString { fn to_string(&self) -> String; }
//
// A unary operation whose implementations must return a builtin `String`.
// -----------------------------------------------------------------------------

#let ToString = operation(
  "example/ToString.to_string",
  1,
  name: "to_string",
)

// -----------------------------------------------------------------------------
// `Into` — the analogue of Rust's `Into<T>` conversion trait.
//
//   trait Into<T> { fn into(self) -> T; }
//
// Spaniel dispatches on the runtime types of the *arguments*, never the return
// type, so we cannot let it infer the target `T` the way Rust does. But an
// operation is identified purely by its `id` string, so we can make `Into`
// itself parametric: a function that folds the target type into a distinct
// operation id. `Into(String)` and `Into(Int)` are then separate dispatch
// families.
//
// `type_key` gives a stable key for any type expression (nominal or applied),
// so the parameter can be a full type such as `array_of(Int)`, not just a
// nominal type.
// -----------------------------------------------------------------------------

#let Into(target) = operation(
  "example/Into[" + type_key(target) + "].into",
  1,
  name: "into[" + display_type(target) + "]",
)

// -----------------------------------------------------------------------------
// `Complex` — a type with real and imaginary parts.
// -----------------------------------------------------------------------------

#let Complex = nominal_type(
  "example/Complex",
  name: "Complex",
  validate: value => (
    type(value) == dictionary
      and "real" in value
      and "imag" in value
      and type(value.real) in (int, float)
      and type(value.imag) in (int, float)
  ),
)

#let complex(real, imag) = object(Complex, (real: real, imag: imag))

// -----------------------------------------------------------------------------
// `impl ToString for Complex` — renders as `x + yi`.
// -----------------------------------------------------------------------------

#let complex_to_string = implementation(
  ToString,
  (Complex,),
  String,
  (ctx, z) => {
    let (real, imag) = z.value
    object(String, str(real) + " + " + str(imag) + "i")
  },
  name: "Complex -> String",
)

// `impl ToString for Int` (the builtin type), so the blanket `Into<String>`
// below has a second type to apply to.
#let int_to_string = implementation(
  ToString,
  (Int,),
  String,
  (ctx, n) => object(String, str(n.value)),
  name: "Int -> String",
)

// -----------------------------------------------------------------------------
// `impl<T: ToString> Into<String> for T`
//
// A single generic (blanket) implementation registered against `Into(String)`:
// any `T` can convert into a `String`, *provided* `T` already implements
// `ToString`. The `requires` constraint is Spaniel's equivalent of Rust's
// `where T: ToString` bound, and the body delegates to `to_string`. The output
// type is the target that parameterises this `Into` family — here, `String`.
// -----------------------------------------------------------------------------

#let T = type_variable("T")

#let into_string_via_to_string = implementation(
  Into(String),
  (T,),
  String,
  (ctx, value) => (ctx.dispatch)(ToString, value),
  constraints: (requires(ToString, (T,), output: String),),
  name: "T -> String where T: ToString",
)

// -----------------------------------------------------------------------------
// A *specific* `impl Into<String> for Complex`, overriding the blanket.
//
// Both this `(Complex,)` implementation and the blanket `(T,)` one match a call
// on a `Complex`, but `(Complex,)` is strictly more specific than `(T,)`, so
// multiple dispatch selects this one — the analogue of a concrete `impl`
// winning over a blanket `impl<T: ..>`. Here it produces a distinct, debug-like
// rendering to make the override observable.
// -----------------------------------------------------------------------------

#let complex_into_string = implementation(
  Into(String),
  (Complex,),
  String,
  (ctx, z) => object(
    String,
    "Complex(" + str(z.value.real) + ", " + str(z.value.imag) + ")",
  ),
  name: "Complex -> String (specific)",
)

// -----------------------------------------------------------------------------
// Assemble the world and expose the operations as functions.
//
// `Into(String)` is called wherever the operation is needed — registering it,
// listing it in the world, and building the dispatcher. Each call rebuilds an
// operation with the *same* id, which is all dispatch compares, so they refer
// to one family.
// -----------------------------------------------------------------------------

#let world = build_world(extension(
  operations: (ToString, Into(String)),
  implementations: (
    complex_to_string,
    int_to_string,
    into_string_via_to_string,
    complex_into_string,
  ),
))

#let to_string = dispatcher(world, ToString)
#let into(ty, x) = dispatcher(world, Into(ty))(x)
// Could also have simply written:
//     #let into_string = dispatcher(world, Into(String))
// And then use:
//     #into_string(z)

// -----------------------------------------------------------------------------
// Usage
// -----------------------------------------------------------------------------

#let z = complex(3, 4)

// `ToString` is unaffected by the `Into` impls.
#to_string(z).value

// `Complex` has a specific `Into(String)` impl, so it wins over the blanket.
#into(String, z).value

// `Int` has no specific `Into(String)` impl, so the blanket applies, routing
// through `ToString`.
#let five = integer(5)
#into(String, five).value

#assert.eq(to_string(z).value, "3 + 4i")
#assert.eq(into(String, z).value, "Complex(3, 4)")
#assert.eq(into(String, five).value, "5")
