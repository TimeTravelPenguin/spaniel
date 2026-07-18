/// Type expressions: the vocabulary used to describe runtime types.
///
/// Defines nominal types, type constructors, and type variables, along with the
/// structural operations the dispatcher relies on — equality, concreteness
/// checks, variable collection, substitution, keying, and display.

/// Construct a nominal runtime type.
///
/// `validate` checks the unboxed payload stored in an object of this type.
///
/// ```example
/// #let Int = nominal_type("demo/Int", name: "Int", validate: v => type(v) == int)
/// #Int.name
/// ```
///
/// -> dictionary
#let nominal_type(
  /// Stable, globally unique identifier for the type.
  /// -> str
  id,
  /// Human-readable display name; defaults to `id`.
  /// -> str | none
  name: none,
  /// Validator for the unboxed payload of objects of this type.
  /// -> function
  validate: value => true,
) = {
  assert(type(id) == str, message: "a type ID must be a string")
  assert(
    type(validate) == function,
    message: "a payload validator must be a function",
  )

  (
    kind: "type.nominal",
    id: id,
    name: if name == none { id } else { name },
    validate: validate,
  )
}

/// Construct an n-ary type constructor, such as `Vector[_]`.
///
/// Its validator receives `(type_arguments, payload)`.
///
/// ```example
/// #let Vector = type_constructor("demo/Vector", 1, name: "Vector")
/// #Vector.arity
/// ```
///
/// -> dictionary
#let type_constructor(
  /// Stable, globally unique identifier for the constructor.
  /// -> str
  id,
  /// Number of type arguments the constructor takes.
  /// -> int
  arity,
  /// Human-readable display name; defaults to `id`.
  /// -> str | none
  name: none,
  /// Validator receiving `(type_arguments, payload)`.
  /// -> function
  validate: (args, value) => true,
) = {
  assert(type(id) == str, message: "a type-constructor ID must be a string")
  assert(
    type(arity) == int and arity >= 0,
    message: "a type-constructor arity must be a non-negative integer",
  )
  assert(
    type(validate) == function,
    message: "a payload validator must be a function",
  )

  (
    kind: "type.constructor",
    id: id,
    arity: arity,
    name: if name == none { id } else { name },
    validate: validate,
  )
}

/// Construct a type variable for use in implementation patterns.
///
/// ```example
/// #repr(type_variable("T"))
/// ```
///
/// -> dictionary
#let type_variable(
  /// The variable's name, e.g. `"T"`.
  /// -> str
  name,
) = {
  assert(type(name) == str, message: "a type-variable name must be a string")

  (
    kind: "type.variable",
    name: name,
  )
}

/// Test whether a value is a well-formed type expression: a nominal type, type
/// variable, valid constructor application, or internal rigid variable.
///
/// ```example
/// #repr((_is_type_expression(Int), _is_type_expression(42)))
/// ```
///
/// -> bool
#let _is_type_expression(
  /// The value to test.
  /// -> any
  value,
) = {
  if type(value) != dictionary or not ("kind" in value) {
    return false
  }

  if value.kind == "type.nominal" or value.kind == "type.variable" {
    return true
  }

  if value.kind == "type.apply" {
    if value.constructor.kind != "type.constructor" {
      return false
    }

    if value.arguments.len() != value.constructor.arity {
      return false
    }

    for argument in value.arguments {
      if not _is_type_expression(argument) {
        return false
      }
    }

    return true
  }

  // Internal rigid variables are produced only while comparing patterns.
  value.kind == "type.rigid"
}


/// Apply a type constructor to type arguments.
///
/// ```example
/// #display_type(apply_type(Array, Int))
/// ```
///
/// -> dictionary
#let apply_type(
  /// The type constructor to apply.
  /// -> dictionary
  constructor,
  /// Type-expression arguments; the count must equal the constructor's arity.
  /// -> arguments
  ..arguments,
) = {
  let arguments = arguments.pos()

  assert(
    constructor.kind == "type.constructor",
    message: "apply_type expects a type constructor",
  )
  assert.eq(
    arguments.len(),
    constructor.arity,
    message: "incorrect number of arguments for " + constructor.name,
  )

  for argument in arguments {
    assert(
      _is_type_expression(argument),
      message: "invalid type argument: " + repr(argument),
    )
  }

  (
    kind: "type.apply",
    constructor: constructor,
    arguments: arguments,
  )
}


/// Test whether two type expressions are structurally equal.
///
/// Ignores validators and display names.
///
/// ```example
/// #repr((type_equal(Int, Int), type_equal(Int, array_of(Int))))
/// ```
///
/// -> bool
#let type_equal(
  /// First type expression.
  /// -> dictionary
  lhs,
  /// Second type expression.
  /// -> dictionary
  rhs,
) = {
  if lhs.kind != rhs.kind {
    return false
  }

  if lhs.kind == "type.nominal" {
    return lhs.id == rhs.id
  }

  if lhs.kind == "type.variable" {
    return lhs.name == rhs.name
  }

  if lhs.kind == "type.rigid" {
    return lhs.id == rhs.id
  }

  if lhs.kind == "type.apply" {
    if lhs.constructor.id != rhs.constructor.id {
      return false
    }

    if lhs.arguments.len() != rhs.arguments.len() {
      return false
    }

    for index in range(lhs.arguments.len()) {
      if not type_equal(lhs.arguments.at(index), rhs.arguments.at(index)) {
        return false
      }
    }

    return true
  }

  false
}

/// Render a type expression as a human-readable string.
///
/// ```example
/// #display_type(array_of(Int))
/// ```
///
/// -> str
#let display_type(
  /// The type expression to render.
  /// -> dictionary
  ty,
) = {
  if ty.kind == "type.nominal" {
    return ty.name
  }

  if ty.kind == "type.variable" {
    return ty.name
  }

  if ty.kind == "type.rigid" {
    return "<" + ty.name + ">"
  }

  if ty.kind == "type.apply" {
    return (
      ty.constructor.name
        + "["
        + ty.arguments.map(display_type).join(", ")
        + "]"
    )
  }

  "<invalid type>"
}

/// A stable key for a type expression or pattern.
///
/// This intentionally ignores validators and display names.
///
/// ```example
/// #type_key(array_of(Int))
/// ```
///
/// -> str
#let type_key(
  /// The type expression to key.
  /// -> dictionary
  ty,
) = {
  if ty.kind == "type.nominal" {
    return "nominal(" + ty.id + ")"
  }

  if ty.kind == "type.variable" {
    return "variable(" + ty.name + ")"
  }

  if ty.kind == "type.rigid" {
    return "rigid(" + ty.id + ")"
  }

  if ty.kind == "type.apply" {
    return (
      "apply("
        + ty.constructor.id
        + ";"
        + ty.arguments.map(type_key).join(";")
        + ")"
    )
  }

  panic("cannot create a key for an invalid type expression")
}

/// Test whether a type expression is fully concrete, i.e. contains no type
/// variables or rigid variables.
///
/// ```example
/// #repr((_is_concrete_type(array_of(Int)), _is_concrete_type(array_of(T))))
/// ```
///
/// -> bool
#let _is_concrete_type(
  /// The type expression to test.
  /// -> dictionary
  ty,
) = {
  if ty.kind == "type.variable" or ty.kind == "type.rigid" {
    return false
  }

  if ty.kind == "type.nominal" {
    return true
  }

  if ty.kind == "type.apply" {
    for argument in ty.arguments {
      if not _is_concrete_type(argument) {
        return false
      }
    }

    return true
  }

  false
}

/// Collect the names of all type variables occurring in `ty`.
///
/// ```example
/// #repr(_type_variables(apply_type(Array, T)))
/// ```
///
/// -> array
#let _type_variables(
  /// The type expression to scan.
  /// -> dictionary
  ty,
) = {
  if ty.kind == "type.variable" {
    return (ty.name,)
  }

  if ty.kind == "type.apply" {
    return ty.arguments.map(_type_variables).flatten().dedup()
  }

  ()
}

/// Substitute type variables in `ty` according to `bindings`.
///
/// Variables absent from `bindings` are left unchanged.
///
/// ```example
/// #display_type(substitute_type(array_of(T), ("T": Int)))
/// ```
///
/// -> dictionary
#let substitute_type(
  /// The type expression to rewrite.
  /// -> dictionary
  ty,
  /// Mapping from variable name to replacement type expression.
  /// -> dictionary
  bindings,
) = {
  if ty.kind == "type.variable" {
    return bindings.at(ty.name, default: ty)
  }

  if ty.kind == "type.apply" {
    return apply_type(
      ty.constructor,
      ..ty.arguments.map(argument => substitute_type(argument, bindings)),
    )
  }

  ty
}

