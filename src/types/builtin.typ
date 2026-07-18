#import "../utils/arrays.typ": single
#import "../types.typ": apply_type, nominal_type, type_constructor
#import "../runtime.typ": object, payload_valid

#let _namespace = "spaniel.types.builtin"

#let Int = nominal_type(
  _namespace + "/Int",
  name: "Int",
  validate: value => type(value) == int,
)

#let UInt = nominal_type(
  _namespace + "/UInt",
  name: "UInt",
  validate: value => type(value) == int and value >= 0,
)

#let Float = nominal_type(
  _namespace + "/Float",
  name: "Float",
  validate: value => type(value) == float,
)

#let Number = nominal_type(
  _namespace + "/Number",
  name: "Number",
  validate: value => type(value) == int or type(value) == float,
)

#let String = nominal_type(
  _namespace + "/String",
  name: "String",
  validate: value => type(value) == str,
)

#let Bool = nominal_type(
  _namespace + "/Bool",
  name: "Bool",
  validate: value => type(value) == bool,
)

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

#let integer(value) = object(Int, value)
#let unsigned_integer(value) = object(UInt, value)
#let floating(value) = object(Float, value)
#let number(value) = object(Number, value)
#let array_of(element_type) = apply_type(Array, element_type)
