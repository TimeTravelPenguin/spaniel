#import "@preview/spaniel:0.1.0": *

// -----------------------------------------------------------------------------
// Types
// -----------------------------------------------------------------------------

#let Int = nominal_type(
  "example.numeric/Int",
  name: "Int",
  validate: value => type(value) == int,
)

#let Vector = type_constructor(
  "example.collection/Vector",
  1,
  name: "Vector",
  validate: (arguments, value) => {
    if type(value) != array {
      return false
    }

    let element_type = arguments.first()

    for element in value {
      if not payload_valid(element_type, element) {
        return false
      }
    }

    true
  },
)

#let vector_of(element_type) = apply_type(Vector, element_type)

#let int(value) = object(Int, value)
#let vector(element_type, values) = object(vector_of(element_type), values)


// -----------------------------------------------------------------------------
// Operation
// -----------------------------------------------------------------------------

#let Mul = operation(
  "example.algebra/Mul.mul",
  2,
  name: "mul",
)


// -----------------------------------------------------------------------------
// Concrete implementations
// -----------------------------------------------------------------------------

#let mul_int_int = implementation(
  Mul,
  (Int, Int),
  Int,
  (ctx, lhs, rhs) => int(lhs.value * rhs.value),
  name: "Int × Int -> Int",
)


// -----------------------------------------------------------------------------
// Generic implementation
//
// S × Vector[T] -> Vector[U], provided S × T -> U exists.
// -----------------------------------------------------------------------------

#let S = type_variable("S")
#let T = type_variable("T")
#let U = type_variable("U")

#let mul_scalar_vector = implementation(
  Mul,
  (S, vector_of(T)),
  vector_of(U),
  (ctx, lhs, rhs) => {
    let input_type = ctx.bindings.at("T")
    let output_type = ctx.bindings.at("U")

    let values = rhs.value.map(value => {
      let element = object(input_type, value)
      (ctx.dispatch)(Mul, lhs, element).value
    })

    vector(output_type, values)
  },
  constraints: (
    requires(Mul, (S, T), output: U),
  ),
  name: "S × Vector[T] -> Vector[U]",
)


// -----------------------------------------------------------------------------
// Registry and public dispatcher
// -----------------------------------------------------------------------------

#let algebra = extension(
  operations: (Mul,),
  implementations: (
    mul_int_int,
    mul_scalar_vector,
  ),
)

#let world = build_world(algebra)
#let mul = dispatcher(world, Mul)


// -----------------------------------------------------------------------------
// Example calls
// -----------------------------------------------------------------------------

#let num = int(42)
#let other_num = int(7)
#let vec = vector(Int, (1, 2, 3))

#let product = mul(num, other_num)
#let scaled = mul(num, vec)

Int product: #product.value

Scaled vector: #repr(scaled.value)

#assert.eq(product.value, 294)
#assert.eq(scaled.value, (42, 84, 126))
