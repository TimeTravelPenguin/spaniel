/// Extensions and world building.
///
/// Bundles operations and implementations into extensions, then validates and
/// merges them into an immutable dispatch world — checking arities, resolving
/// references, rejecting duplicates, and ensuring every type variable is bound.

#import "types.typ": _type_variables, type_key

/// Bundle operations and implementations into an extension for @build_world.
///
/// ```example
/// #extension(operations: (Mul,), implementations: (mul_int_int,)).operations.len()
/// ```
///
/// -> dictionary
#let extension(
  /// Operations declared by this extension.
  /// -> array
  operations: (),
  /// Implementations provided by this extension.
  /// -> array
  implementations: (),
) = (
  kind: "extension",
  operations: operations,
  implementations: implementations,
)

/// Build a stable string key identifying a constraint, used to detect
/// duplicate implementations.
///
/// ```example
/// #_constraint_key(requires(Mul, (Int, Int)))
/// ```
///
/// -> str
#let _constraint_key(
  /// The constraint to key.
  /// -> dictionary
  constraint,
) = {
  if constraint.kind == "constraint.requires" {
    return (
      "requires("
        + constraint.operation.id
        + ";"
        + constraint.inputs.map(type_key).join(";")
        + ";"
        + (
          if constraint.output == none { "none" } else {
            type_key(constraint.output)
          }
        )
        + ")"
    )
  }

  panic("unknown constraint kind: " + constraint.kind)
}

/// Build a stable string key identifying an implementation by its operation,
/// input and output types, constraints, and priority.
///
/// ```example
/// #_implementation_key(mul_int_int)
/// ```
///
/// -> str
#let _implementation_key(
  /// The implementation to key.
  /// -> dictionary
  implementation,
) = (
  implementation.operation.id
    + "("
    + implementation.inputs.map(type_key).join(",")
    + ")->"
    + type_key(implementation.output)
    + " where "
    + implementation.constraints.map(_constraint_key).join(",")
    + " @"
    + str(implementation.priority)
)

/// Assert that every type variable used by an implementation's constraints and
/// output is bound by its input patterns (or by an earlier constraint output),
/// panicking with a descriptive message otherwise.
///
/// ```example
/// #{
///   _validate_implementation_variables(mul_scalar_vector)
///   "validated: every type variable is bound"
/// }
/// ```
///
/// -> none
#let _validate_implementation_variables(
  /// The implementation to check.
  /// -> dictionary
  implementation,
) = {
  let bound = (:)

  for variable in implementation.inputs.map(_type_variables).flatten().dedup() {
    bound.insert(variable, true)
  }

  for constraint in implementation.constraints {
    assert(
      constraint.kind == "constraint.requires",
      message: "unknown constraint kind in " + implementation.name,
    )

    for variable in constraint.inputs.map(_type_variables).flatten().dedup() {
      assert(
        variable in bound,
        message: (
          "constraint in "
            + implementation.name
            + " uses unbound type variable "
            + variable
        ),
      )
    }

    if constraint.output != none {
      for variable in _type_variables(constraint.output) {
        bound.insert(variable, true)
      }
    }
  }

  for variable in _type_variables(implementation.output) {
    assert(
      variable in bound,
      message: (
        "output of "
          + implementation.name
          + " contains unbound type variable "
          + variable
      ),
    )
  }
}

/// Combine extensions into a validated immutable dispatch world.
///
/// ```example
/// #let w = build_world(algebra)
/// #w.implementations.len()
/// ```
///
/// -> dictionary
#let build_world(
  /// The extensions to combine, each produced by @extension.
  /// -> arguments
  ..extensions,
) = {
  let extensions = extensions.pos()
  let operations = (:)
  let implementations = ()
  let seen_implementations = (:)

  for extension in extensions {
    assert(
      extension.kind == "extension",
      message: "build_world expects extensions",
    )

    for operation in extension.operations {
      if operation.id in operations {
        let existing = operations.at(operation.id)
        assert.eq(
          existing.arity,
          operation.arity,
          message: "operation "
            + operation.id
            + " was declared with conflicting arities",
        )
      } else {
        operations.insert(operation.id, operation)
      }
    }

    implementations += extension.implementations
  }

  for implementation in implementations {
    assert(
      implementation.operation.id in operations,
      message: "implementation refers to undeclared operation "
        + implementation.operation.id,
    )

    assert.eq(
      operations.at(implementation.operation.id).arity,
      implementation.inputs.len(),
      message: "implementation arity mismatch for " + implementation.name,
    )

    for constraint in implementation.constraints {
      assert(
        constraint.operation.id in operations,
        message: (
          "constraint in "
            + implementation.name
            + " refers to undeclared operation "
            + constraint.operation.id
        ),
      )
    }

    _validate_implementation_variables(implementation)

    let key = _implementation_key(implementation)
    assert(
      not (key in seen_implementations),
      message: "duplicate implementation: " + implementation.name,
    )
    seen_implementations.insert(key, true)
  }

  (
    kind: "dispatch.world",
    operations: operations,
    implementations: implementations,
  )
}


