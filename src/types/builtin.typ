/// Ready-made runtime types for Typst's built-in value kinds.
///
/// A convenience layer over `nominal_type` and `type_constructor`: nominal types
/// mirroring Typst's primitives (`int`, `float`, `str`, `bool`), a couple of
/// refinements (`UInt`, `Number`), the `Array[_]` constructor, and paired
/// constructor functions that box a raw value as the matching object.

#import "../utils/arrays.typ": single
#import "../types.typ": apply_type, nominal_type, type_constructor
#import "../runtime.typ": object, payload_valid

/// Shared id prefix for the built-in types, keeping their ids unique and
/// namespaced apart from user-defined types.
///
/// ```example
/// #_namespace
/// ```
///
/// -> str
#let _namespace = "spaniel.types.builtin"

/// The type of Typst integers.
///
/// ```example
/// #repr((payload_valid(Int, 42), payload_valid(Int, 4.2)))
/// ```
///
/// -> dictionary
#let Int = nominal_type(
  _namespace + "/Int",
  name: "Int",
  validate: value => type(value) == int,
)

/// The type of non-negative Typst integers.
///
/// ```example
/// #repr((payload_valid(UInt, 7), payload_valid(UInt, -1)))
/// ```
///
/// -> dictionary
#let UInt = nominal_type(
  _namespace + "/UInt",
  name: "UInt",
  validate: value => type(value) == int and value >= 0,
)

/// The type of Typst floating-point numbers.
///
/// ```example
/// #repr((payload_valid(Float, 3.14), payload_valid(Float, 3)))
/// ```
///
/// -> dictionary
#let Float = nominal_type(
  _namespace + "/Float",
  name: "Float",
  validate: value => type(value) == float,
)

/// The type of Typst numbers — either an `int` or a `float`.
///
/// ```example
/// #repr((payload_valid(Number, 3), payload_valid(Number, 3.14)))
/// ```
///
/// -> dictionary
#let Number = nominal_type(
  _namespace + "/Number",
  name: "Number",
  validate: value => type(value) == int or type(value) == float,
)

/// The type of Typst strings.
///
/// ```example
/// #repr((payload_valid(String, "hi"), payload_valid(String, 5)))
/// ```
///
/// -> dictionary
#let String = nominal_type(
  _namespace + "/String",
  name: "String",
  validate: value => type(value) == str,
)

/// The type of Typst booleans.
///
/// ```example
/// #repr((payload_valid(Bool, true), payload_valid(Bool, 1)))
/// ```
///
/// -> dictionary
#let Bool = nominal_type(
  _namespace + "/Bool",
  name: "Bool",
  validate: value => type(value) == bool,
)

/// The `Array[T]` type constructor: an array whose every element is a valid `T`.
///
/// The contract is recursive — element validity is delegated to `payload_valid`
/// against the element type argument.
///
/// ```example
/// #display_type(array_of(String))
/// ```
///
/// -> dictionary
#let Array = type_constructor(
  _namespace + "/Array",
  1,
  name: "Array",
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

/// Box a raw integer as an @Int object.
///
/// ```example
/// #integer(42).value
/// ```
///
/// -> dictionary
#let integer(
  /// The integer to box.
  /// -> int
  value,
) = object(Int, value)

/// Box a raw non-negative integer as a @UInt object.
///
/// ```example
/// #unsigned_integer(7).value
/// ```
///
/// -> dictionary
#let unsigned_integer(
  /// The non-negative integer to box.
  /// -> int
  value,
) = object(UInt, value)

/// Box a raw float as a @Float object.
///
/// ```example
/// #floating(3.5).value
/// ```
///
/// -> dictionary
#let floating(
  /// The float to box.
  /// -> float
  value,
) = object(Float, value)

/// Box a raw number (`int` or `float`) as a @Number object.
///
/// ```example
/// #number(2).value
/// ```
///
/// -> dictionary
#let number(
  /// The number to box.
  /// -> int | float
  value,
) = object(Number, value)

/// Box a raw boolean as a @Bool object.
///
/// ```example
/// #boolean(false).value
/// ```
///
/// -> dictionary
#let boolean(
  /// The boolean to box.
  /// -> bool
  value,
) = object(Bool, value)

/// Box a raw string as a @String object.
///
/// ```example
/// #string("hi").value
/// ```
///
/// -> dictionary
#let string(
  /// The string to box.
  /// -> str
  value,
) = object(String, value)

/// Apply @Array to an element type, yielding the type expression `Array[T]`.
///
/// ```example
/// #display_type(array_of(Bool))
/// ```
///
/// -> dictionary
#let array_of(
  /// The element type `T`.
  /// -> dictionary
  element_type,
) = apply_type(Array, element_type)
