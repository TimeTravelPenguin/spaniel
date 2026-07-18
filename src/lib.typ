/// Public entrypoint for the `spaniel` package.
///
/// Re-exports the curated public API from each submodule: type expressions,
/// runtime objects, operation and implementation declarations, extension
/// registration, and the dispatcher. Internal helpers (underscore-prefixed)
/// stay private to their modules.

#import "types/builtin.typ": (
  Array, Bool, Float, Int, Number, String, UInt, array_of, boolean, floating,
  integer, number, string, unsigned_integer,
)
#import "types.typ": (
  apply_type, display_type, nominal_type, substitute_type, type_constructor,
  type_equal, type_key, type_variable,
)
#import "runtime.typ": is_object, object, payload_valid, runtime_type
#import "operations.typ": implementation, operation, requires
#import "registry.typ": build_world, extension
#import "dispatch.typ": dispatch, dispatcher, try_resolve
