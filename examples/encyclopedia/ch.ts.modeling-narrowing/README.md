# Modeling and narrowing example

This self-contained example keeps API input as `unknown`, validates own fields at runtime, maps valid data into a domain object, and renders a discriminated loading-state union with a `never` exhaustiveness boundary.

Run:

    ./verify.sh

The verifier uses the frozen TypeScript 7.0.2 dependency, performs a strict no-emit check, emits JavaScript, and compares runtime guard cases with `expected.stdout`. The package declares Node 24.x; running elsewhere is not Node 24 verification.
