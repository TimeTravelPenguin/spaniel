#import "/src/lib.typ": *
#import "/src/lib.typ" as m-lib
#import "/src/internal.typ" as m-internal
#import "/src/types.typ" as m-types
#import "/src/matching.typ" as m-matching
#import "/src/registry.typ" as m-registry
#import "/src/dispatch.typ" as m-dispatch

#let Int = nominal_type(
  "demo/Int",
  name: "Int",
  validate: value => type(value) == int,
)
#let integer = value => object(Int, value)

#let Vector = type_constructor(
  "demo/Vector",
  1,
  name: "Vector",
  validate: (arguments, value) => (
    type(value) == array
      and value.all(element => payload_valid(arguments.first(), element))
  ),
)
#let vector_of = element_type => apply_type(Vector, element_type)
#let vector = (element_type, values) => object(vector_of(element_type), values)

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
  (S, vector_of(T)),
  vector_of(U),
  (ctx, lhs, rhs) => vector(
    ctx.bindings.at("U"),
    rhs.value.map(value => (
      (ctx.dispatch)(Mul, lhs, object(ctx.bindings.at("T"), value)).value
    )),
  ),
  constraints: (requires(Mul, (S, T), output: U),),
  name: "S × Vector[T] -> Vector[U]",
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
    + (
      Int: Int,
      int: integer,
      Vector: Vector,
      vector_of: vector_of,
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
