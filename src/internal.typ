/// Internal result type.
///
/// Lightweight `ok`/`err` values used to thread fallible computations — type
/// matching, constraint solving, and resolution — without panicking, so that
/// callers can report rich diagnostics instead.

/// Wrap a value as a successful result.
///
/// ```example
/// #repr(_ok(42))
/// ```
///
/// -> dictionary
#let _ok(
  /// The success payload.
  /// -> any
  value,
) = (
  kind: "result.ok",
  value: value,
)

/// Wrap a message as a failed result.
///
/// ```example
/// #repr(_err("no matching implementation"))
/// ```
///
/// -> dictionary
#let _err(
  /// The error message.
  /// -> str
  message,
) = (
  kind: "result.err",
  message: message,
)

/// Test whether a result is successful.
///
/// ```example
/// #repr((_is_ok(_ok(1)), _is_ok(_err("boom"))))
/// ```
///
/// -> bool
#let _is_ok(
  /// The result to test.
  /// -> dictionary
  result,
) = result.kind == "result.ok"
