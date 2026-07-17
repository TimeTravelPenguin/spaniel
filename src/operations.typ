/// Operations, requirements, and implementations.
///
/// The declarations an author writes to describe a generic operation, the
/// implementations that satisfy it for particular type patterns, and the
/// requirements one implementation may place on others.

#import "types.typ": _is_type_expression

/// Declare an operation: a named, fixed-arity dispatch point that
/// implementations can be registered against.
///
/// ```example
/// #let Mul = operation("demo/Mul.mul", 2, name: "mul")
/// #Mul.arity
/// ```
///
/// -> dictionary
#let operation(
  /// Stable, globally unique identifier for the operation.
  /// -> str
  id,
  /// Number of object arguments the operation accepts.
  /// -> int
  arity,
  /// Human-readable display name; defaults to `id`.
  /// -> str | none
  name: none,
) = {
  assert(type(id) == str, message: "an operation ID must be a string")
  assert(
    type(arity) == int and arity >= 0,
    message: "an operation arity must be a non-negative integer",
  )

  (
    kind: "operation",
    id: id,
    arity: arity,
    name: if name == none { id } else { name },
  )
}

/// Require another operation to be resolvable while checking an implementation.
///
/// `inputs` is an array of type expressions. If `output` is supplied, matching
/// the required operation's output against it may introduce new bindings.
///
/// ```example
/// #repr(requires(Mul, (S, T), output: U).inputs.map(display_type))
/// ```
///
/// -> dictionary
#let requires(
  /// The operation that must be resolvable.
  /// -> dictionary
  operation,
  /// Input type expressions for the required call; must match `operation`'s arity.
  /// -> array
  inputs,
  /// Optional output type expression to match the required operation's output against.
  /// -> dictionary | none
  output: none,
) = {
  assert(
    operation.kind == "operation",
    message: "requires expects an operation",
  )
  assert(type(inputs) == array, message: "requirement inputs must be an array")
  assert.eq(
    inputs.len(),
    operation.arity,
    message: "requirement arity does not match its operation",
  )

  (
    kind: "constraint.requires",
    operation: operation,
    inputs: inputs,
    output: output,
  )
}

/// Declare an implementation of an operation.
///
/// The body is called as `body(context, ..objects)`.
///
/// ```example
/// #let mul-ii = implementation(
///   Mul, (Int, Int), Int,
///   (ctx, lhs, rhs) => object(Int, lhs.value * rhs.value),
///   name: "Int × Int -> Int",
/// )
/// #mul-ii.name
/// ```
///
/// -> dictionary
#let implementation(
  /// The operation being implemented.
  /// -> dictionary
  operation,
  /// Input type patterns, one per argument; may contain type variables.
  /// -> array
  inputs,
  /// Output type expression produced by the implementation.
  /// -> dictionary
  output,
  /// Implementation body, called as `body(context, ..objects)`.
  /// -> function
  body,
  /// Requirements (see @requires) that must hold for this implementation to apply.
  /// -> array
  constraints: (),
  /// Human-readable display name; defaults to the operation's name.
  /// -> str | none
  name: none,
  /// Tie-breaking priority among equally specific implementations; higher wins.
  /// -> int
  priority: 0,
) = {
  assert(
    operation.kind == "operation",
    message: "implementation expects an operation",
  )
  assert(
    type(inputs) == array,
    message: "implementation inputs must be an array",
  )
  assert.eq(
    inputs.len(),
    operation.arity,
    message: "implementation arity does not match its operation",
  )
  assert(
    _is_type_expression(output),
    message: "invalid implementation output type",
  )
  assert(
    type(body) == function,
    message: "an implementation body must be a function",
  )
  assert(
    type(constraints) == array,
    message: "implementation constraints must be an array",
  )
  assert(
    type(priority) == int,
    message: "implementation priority must be an integer",
  )

  for input in inputs {
    assert(
      _is_type_expression(input),
      message: "invalid implementation input type",
    )
  }

  (
    kind: "implementation",
    operation: operation,
    inputs: inputs,
    output: output,
    body: body,
    constraints: constraints,
    name: if name == none { operation.name } else { name },
    priority: priority,
  )
}
