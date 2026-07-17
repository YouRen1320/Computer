# TypeScript foundations example

This isolated asset fixes TypeScript 7.0.2, checks strict source with noEmit, emits to a disposable directory, runs the JavaScript result, and then calls the emitted function from unchecked JavaScript to prove that a number annotation is not runtime validation.

Run:

    ./verify.sh

The manifests declare Node 24.x and pnpm 11.11.0 as the canonical target. A run on any other local versions is only a local mechanical result and must be reported as such.
