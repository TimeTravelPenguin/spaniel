#let single(arr) = {
  assert.eq(
    type(arr),
    array,
    message: "Expected an array, got: " + type(arr),
  )
  assert.eq(
    arr.len(),
    1,
    message: "Expected an array of length 1, got: " + arr.len(),
  )

  arr.first()
}
