/// Multiple dispatch.
///
/// Resolves an operation against a world by selecting the single most-specific
/// implementation for the argument types — recursively satisfying constraints
/// and guarding against cycles — then invokes it and revalidates its result.

#import "internal.typ": _err, _is_ok, _ok
#import "types.typ": (
  _is_concrete_type, display_type, substitute_type, type_equal, type_key,
)
#import "matching.typ": _match_signature, _match_type, _more_specific
#import "runtime.typ": is_object, payload_valid, runtime_type

/// Build a stable string key for a call site — an operation plus its concrete
/// argument types — used to detect cyclic requirement resolution.
///
/// ```example
/// #_call_key(Mul, (Int, Int))
/// ```
///
/// -> str
#let _call_key(
  /// The operation being called.
  /// -> dictionary
  operation,
  /// The concrete argument types of the call.
  /// -> array
  actual_types,
) = (
  operation.id + "(" + actual_types.map(type_key).join(",") + ")"
)

/// Core resolution routine: find the single most-specific implementation of
/// `operation` for `actual_types`, recursively satisfying each implementation's
/// constraints and guarding against cycles via `stack`. Returns an `ok` result
/// carrying the chosen candidate, or an `err` describing why resolution failed.
///
/// ```example
/// #let resolved = _resolve(world, Mul, (Int, Int), ())
/// #resolved.value.implementation.name
/// ```
///
/// -> dictionary
#let _resolve(
  /// The dispatch world to resolve against.
  /// -> dictionary
  world,
  /// The operation to resolve.
  /// -> dictionary
  operation,
  /// The concrete argument types.
  /// -> array
  actual_types,
  /// Call keys currently being resolved, used for cycle detection.
  /// -> array
  stack,
) = {
  // Kept local so recursive requirement resolution depends only on `_resolve`,
  // rather than on mutually recursive top-level bindings.
  let satisfy_constraints(implementation, initial_bindings, stack) = {
    let bindings = initial_bindings

    for constraint in implementation.constraints {
      if constraint.kind != "constraint.requires" {
        return _err("unknown constraint kind: " + constraint.kind)
      }

      let required_inputs = constraint.inputs.map(
        input => substitute_type(input, bindings),
      )

      for input in required_inputs {
        if not _is_concrete_type(input) {
          return _err(
            "constraint for "
              + implementation.name
              + " contains an unresolved input type "
              + display_type(input),
          )
        }
      }

      let required = _resolve(
        world,
        constraint.operation,
        required_inputs,
        stack,
      )

      if not _is_ok(required) {
        return _err(
          "constraint for "
            + implementation.name
            + " was not satisfied: "
            + required.message,
        )
      }

      if constraint.output != none {
        let matched_output = _match_type(
          constraint.output,
          required.value.output,
          bindings,
        )

        if not _is_ok(matched_output) {
          return _err(
            "required output for "
              + implementation.name
              + " did not match: "
              + matched_output.message,
          )
        }

        bindings = matched_output.value
      }
    }

    _ok(bindings)
  }

  if not (operation.id in world.operations) {
    return _err("unknown operation " + operation.id)
  }

  if actual_types.len() != operation.arity {
    return _err(
      "operation "
        + operation.name
        + " expects "
        + str(operation.arity)
        + " arguments, received "
        + str(actual_types.len()),
    )
  }

  let key = _call_key(operation, actual_types)

  if key in stack {
    return _err("cyclic requirement while resolving " + key)
  }

  let next_stack = stack + (key,)
  let candidates = ()
  let rejected = ()

  for implementation in world.implementations {
    if implementation.operation.id == operation.id {
      let matched = _match_signature(implementation.inputs, actual_types)

      if _is_ok(matched) {
        let constrained = satisfy_constraints(
          implementation,
          matched.value,
          next_stack,
        )

        if _is_ok(constrained) {
          let output = substitute_type(implementation.output, constrained.value)

          if _is_concrete_type(output) {
            candidates.push((
              implementation: implementation,
              bindings: constrained.value,
              output: output,
            ))
          } else {
            rejected.push(
              implementation.name
                + ": unresolved output type "
                + display_type(output),
            )
          }
        } else {
          rejected.push(implementation.name + ": " + constrained.message)
        }
      }
    }
  }

  if candidates.len() == 0 {
    let message = (
      "no implementation of "
        + operation.name
        + " matches ("
        + actual_types.map(display_type).join(", ")
        + ")"
    )

    if rejected.len() > 0 {
      message += ". Rejected candidates: " + rejected.join("; ")
    }

    return _err(message)
  }

  let maximal = ()

  for index in range(candidates.len()) {
    let candidate = candidates.at(index)
    let dominated = false

    for other_index in range(candidates.len()) {
      if other_index != index {
        let other = candidates.at(other_index)

        if _more_specific(
          other.implementation,
          candidate.implementation,
        ) {
          dominated = true
        }
      }
    }

    if not dominated {
      maximal.push(candidate)
    }
  }

  let greatest_priority = maximal.first().implementation.priority

  for candidate in maximal {
    if candidate.implementation.priority > greatest_priority {
      greatest_priority = candidate.implementation.priority
    }
  }

  let best = maximal.filter(
    candidate => candidate.implementation.priority == greatest_priority,
  )

  if best.len() != 1 {
    return _err(
      "ambiguous implementations of "
        + operation.name
        + " for ("
        + actual_types.map(display_type).join(", ")
        + "): "
        + best.map(candidate => candidate.implementation.name).join(", "),
    )
  }

  _ok(best.first())
}

/// Resolve an operation for concrete type descriptors without invoking it.
///
/// ```example
/// #display_type(try_resolve(world, Mul, (Int, array_of(Int))).value.output)
/// ```
///
/// -> dictionary
#let try_resolve(
  /// The dispatch world to resolve against.
  /// -> dictionary
  world,
  /// The operation to resolve.
  /// -> dictionary
  operation,
  /// Concrete type descriptors for each argument.
  /// -> array
  actual_types,
) = {
  assert(
    world.kind == "dispatch.world",
    message: "try_resolve expects a dispatch world",
  )
  _resolve(world, operation, actual_types, ())
}

/// Invoke an operation using multiple dispatch.
///
/// ```example
/// #repr(dispatch(world, Mul, integer(2), vector(Int, (1, 2, 3))).value)
/// ```
///
/// -> dictionary
#let dispatch(
  /// The dispatch world to resolve against.
  /// -> dictionary
  world,
  /// The operation to invoke.
  /// -> dictionary
  operation,
  /// The object arguments to dispatch on.
  /// -> arguments
  ..arguments,
) = {
  let arguments = arguments.pos()
  let actual_types = arguments.map(runtime_type)
  let resolved = _resolve(world, operation, actual_types, ())

  if not _is_ok(resolved) {
    panic(resolved.message)
  }

  let selected = resolved.value
  let ctx = (
    world: world,
    bindings: selected.bindings,
    dispatch: dispatch.with(world),
    resolve: try_resolve.with(world),
  )

  let result = (selected.implementation.body)(ctx, ..arguments)

  assert(
    is_object(result),
    message: "implementation "
      + selected.implementation.name
      + " returned a non-object",
  )

  assert(
    type_equal(runtime_type(result), selected.output),
    message: (
      "implementation "
        + selected.implementation.name
        + " returned "
        + display_type(runtime_type(result))
        + ", expected "
        + display_type(selected.output)
    ),
  )

  // Revalidate the payload in case an implementation forged the object shape.
  assert(
    payload_valid(result.ty, result.value),
    message: "implementation "
      + selected.implementation.name
      + " returned an invalid payload",
  )

  result
}

/// Produce a convenient operation-specific function.
///
/// ```example
/// #let mul = dispatcher(world, Mul)
/// #mul(integer(6), integer(7)).value
/// ```
///
/// -> function
#let dispatcher(
  /// The dispatch world to bind.
  /// -> dictionary
  world,
  /// The operation to bind.
  /// -> dictionary
  operation,
) = dispatch.with(world, operation)

