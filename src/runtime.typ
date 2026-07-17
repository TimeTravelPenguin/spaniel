/// Runtime objects: values boxed together with their runtime type.
///
/// Provides the boxing constructor and the predicates that let the dispatcher
/// recognise objects, read their type, and validate their payloads.

#import "types.typ": _is_concrete_type, display_type

/// Validate an unboxed value against a concrete runtime type.
///
/// ```example
/// #repr((payload_valid(Int, 42), payload_valid(Int, "oops")))
/// ```
///
/// -> bool
#let payload_valid(
  /// The concrete type to validate against.
  /// -> dictionary
  ty,
  /// The unboxed value to check.
  /// -> any
  value,
) = {
  if ty.kind == "type.nominal" {
    return (ty.validate)(value)
  }

  if ty.kind == "type.apply" {
    return (ty.constructor.validate)(ty.arguments, value)
  }

  false
}

/// Box an unboxed Typst value with a user-defined runtime type.
///
/// ```example
/// #object(Int, 42).value
/// ```
///
/// -> dictionary
#let object(
  /// The concrete runtime type to attach.
  /// -> dictionary
  ty,
  /// The unboxed value to box.
  /// -> any
  value,
) = {
  assert(
    _is_concrete_type(ty),
    message: "objects require a concrete runtime type",
  )
  assert(
    payload_valid(ty, value),
    message: "invalid payload for " + display_type(ty) + ": " + repr(value),
  )

  (
    kind: "object",
    ty: ty,
    value: value,
  )
}

/// Test whether a value is a protocol object.
///
/// ```example
/// #repr((is_object(object(Int, 42)), is_object(42)))
/// ```
///
/// -> bool
#let is_object(
  /// The value to test.
  /// -> any
  value,
) = (
  type(value) == dictionary
    and "kind" in value
    and value.kind == "object"
    and "ty" in value
    and "value" in value
)

/// Return the runtime type of a protocol object.
///
/// ```example
/// #display_type(runtime_type(object(Int, 42)))
/// ```
///
/// -> dictionary
#let runtime_type(
  /// The protocol object to inspect.
  /// -> dictionary
  value,
) = {
  assert(
    is_object(value),
    message: "expected a protocol object, found " + repr(value),
  )
  value.ty
}
