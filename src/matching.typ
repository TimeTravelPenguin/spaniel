/// Pattern matching and specificity.
///
/// Matches type patterns against concrete types (accumulating type-variable
/// bindings) and decides when one implementation's signature is strictly more
/// specific than another's, which drives overload selection in the dispatcher.

#import "internal.typ": _err, _is_ok, _ok
#import "types.typ": apply_type, display_type, type_equal

/// Match a single type `pattern` against an `actual` type, extending
/// `bindings` with any type variables resolved along the way.
///
/// ```example
/// #let matched = _match_type(T, Int, (:))
/// #display_type(matched.value.at("T"))
/// ```
///
/// -> dictionary
#let _match_type(
  /// The type pattern to match; may contain type variables.
  /// -> dictionary
  pattern,
  /// The concrete type to match against.
  /// -> dictionary
  actual,
  /// Type-variable bindings accumulated so far.
  /// -> dictionary
  bindings,
) = {
  if pattern.kind == "type.variable" {
    if pattern.name in bindings {
      if type_equal(bindings.at(pattern.name), actual) {
        return _ok(bindings)
      }

      return _err(
        "type variable "
          + pattern.name
          + " was already bound to "
          + display_type(bindings.at(pattern.name))
          + ", but also matched "
          + display_type(actual),
      )
    }

    let updated = bindings
    updated.insert(pattern.name, actual)
    return _ok(updated)
  }

  if pattern.kind == "type.nominal" {
    if actual.kind == "type.nominal" and pattern.id == actual.id {
      return _ok(bindings)
    }

    return _err(
      display_type(pattern) + " does not match " + display_type(actual),
    )
  }

  if pattern.kind == "type.rigid" {
    if actual.kind == "type.rigid" and pattern.id == actual.id {
      return _ok(bindings)
    }

    return _err(
      display_type(pattern) + " does not match " + display_type(actual),
    )
  }

  if pattern.kind == "type.apply" {
    if actual.kind != "type.apply" {
      return _err(
        display_type(pattern) + " does not match " + display_type(actual),
      )
    }

    if pattern.constructor.id != actual.constructor.id {
      return _err(
        display_type(pattern) + " does not match " + display_type(actual),
      )
    }

    let current = bindings

    for index in range(pattern.arguments.len()) {
      let matched = _match_type(
        pattern.arguments.at(index),
        actual.arguments.at(index),
        current,
      )

      if not _is_ok(matched) {
        return matched
      }

      current = matched.value
    }

    return _ok(current)
  }

  _err("invalid type pattern: " + repr(pattern))
}

/// Match a whole signature: each pattern against the corresponding actual
/// type, threading one shared set of bindings across all positions.
///
/// ```example
/// #let b = _match_signature((S, vector_of(T)), (Int, vector_of(Int))).value
/// #(display_type(b.at("S")) + ", " + display_type(b.at("T")))
/// ```
///
/// -> dictionary
#let _match_signature(
  /// The input type patterns of an implementation.
  /// -> array
  patterns,
  /// The concrete argument types of a call.
  /// -> array
  actual_types,
) = {
  if patterns.len() != actual_types.len() {
    return _err("signature arity mismatch")
  }

  let bindings = (:)

  for index in range(patterns.len()) {
    let matched = _match_type(
      patterns.at(index),
      actual_types.at(index),
      bindings,
    )

    if not _is_ok(matched) {
      return matched
    }

    bindings = matched.value
  }

  _ok(bindings)
}

/// Replace every type variable in `ty` with a fresh rigid variable, tagged by
/// `prefix`, so it matches only itself. Used to make a signature's variables
/// opaque while testing subsumption.
///
/// ```example
/// #display_type(_skolemize_type(vector_of(T), "impl"))
/// ```
///
/// -> dictionary
#let _skolemize_type(
  /// The type expression to rigidify.
  /// -> dictionary
  ty,
  /// A prefix that makes the generated rigid variables unique.
  /// -> str
  prefix,
) = {
  if ty.kind == "type.variable" {
    return (
      kind: "type.rigid",
      id: prefix + "/" + ty.name,
      name: ty.name,
    )
  }

  if ty.kind == "type.apply" {
    return apply_type(
      ty.constructor,
      ..ty.arguments.map(argument => _skolemize_type(argument, prefix)),
    )
  }

  ty
}

/// Test whether `general` subsumes `specific`: every call described by
/// `specific` is also described by `general`. The variables in `specific` are
/// made rigid (via `prefix`) so only `general` may generalise over them.
///
/// ```example
/// #repr((
///   _signature_subsumes((S,), (Int,), "a"),
///   _signature_subsumes((Int,), (S,), "b"),
/// ))
/// ```
///
/// -> bool
#let _signature_subsumes(
  /// The candidate more-general signature (its variables stay flexible).
  /// -> array
  general,
  /// The candidate more-specific signature (its variables are made rigid).
  /// -> array
  specific,
  /// A prefix that makes the rigidified variables unique.
  /// -> str
  prefix,
) = {
  let rigid_specific = specific.map(pattern => _skolemize_type(pattern, prefix))
  _is_ok(_match_signature(general, rigid_specific))
}

/// Test whether implementation `lhs` is strictly more specific than `rhs`:
/// `rhs` accepts every call `lhs` does, but not vice versa.
///
/// ```example
/// #let generic = implementation(Mul, (S, T), Int, (ctx, l, r) => l, name: "generic")
/// #let specific = implementation(Mul, (Int, Int), Int, (ctx, l, r) => l, name: "specific")
/// #repr((_more_specific(specific, generic), _more_specific(generic, specific)))
/// ```
///
/// -> bool
#let _more_specific(
  /// The implementation being tested for greater specificity.
  /// -> dictionary
  lhs,
  /// The implementation to compare against.
  /// -> dictionary
  rhs,
) = {
  let rhs_accepts_lhs = _signature_subsumes(
    rhs.inputs,
    lhs.inputs,
    "lhs",
  )

  let lhs_accepts_rhs = _signature_subsumes(
    lhs.inputs,
    rhs.inputs,
    "rhs",
  )

  rhs_accepts_lhs and not lhs_accepts_rhs
}
