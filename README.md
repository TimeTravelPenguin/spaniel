<p align="center">
  <img src="./assets/spaniel.png" alt="project logo" width="300">
</p>

<h1 align="center">Spaniel</h1>

Spaniel is a Typst package for implementing stricter library code where "objects" follow
certain contracts. Rather than enforcing project-dependent code styles to enforce
practices and consistency throughout code, this package aims to help enforce this at the
API level.

To illustrate, a package author might define an "object" like:
```typ
#let complex(real, imag) = (tag: "complex", real: real, imag: imag)

#let vector(values) = (tag: "vector", values: values)
```
