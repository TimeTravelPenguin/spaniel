#import "/src/lib.typ": *
#import "/src/types/builtin.typ": Int, array_of
#import "/src/lib.typ" as m-lib
#import "/src/internal.typ" as m-internal
#import "/src/types.typ" as m-types
#import "/src/matching.typ" as m-matching
#import "/src/registry.typ" as m-registry
#import "/src/dispatch.typ" as m-dispatch
#import "/src/types/builtin.typ" as m-builtin

// `Int` and the `Array[_]` type (`array_of`) are provided natively by
// `src/types/builtin.typ`, so the examples use those directly. The library has
// no single-call constructor for a boxed array value, so this small helper
// stays a fixture.
#let vector = (element_type, values) => object(array_of(element_type), values)

#let Mul = operation("demo/Mul.mul", 2, name: "mul")

#let mul_int_int = implementation(
  Mul,
  (Int, Int),
  Int,
  (ctx, lhs, rhs) => object(Int, lhs.value * rhs.value),
  name: "Int × Int -> Int",
)

#let S = type_variable("S")
#let T = type_variable("T")
#let U = type_variable("U")

#let mul_scalar_vector = implementation(
  Mul,
  (S, array_of(T)),
  array_of(U),
  (ctx, lhs, rhs) => vector(
    ctx.bindings.at("U"),
    rhs.value.map(value => (
      (ctx.dispatch)(Mul, lhs, object(ctx.bindings.at("T"), value)).value
    )),
  ),
  constraints: (requires(Mul, (S, T), output: U),),
  name: "S × Array[T] -> Array[U]",
)

#let algebra = extension(
  operations: (Mul,),
  implementations: (mul_int_int, mul_scalar_vector),
)
#let world = build_world(algebra)
#let mul = dispatcher(world, Mul)

#let example-scope = (
  dictionary(m-lib)
    + dictionary(m-internal)
    + dictionary(m-types)
    + dictionary(m-matching)
    + dictionary(m-registry)
    + dictionary(m-dispatch)
    + dictionary(m-builtin)
    + (
      vector: vector,
      Mul: Mul,
      mul_int_int: mul_int_int,
      S: S,
      T: T,
      U: U,
      mul_scalar_vector: mul_scalar_vector,
      algebra: algebra,
      world: world,
      mul: mul,
    )
)
