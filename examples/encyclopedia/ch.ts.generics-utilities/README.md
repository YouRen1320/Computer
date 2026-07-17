# Generics and utilities example

This self-contained example demonstrates a relationship-preserving field selector, a domain-specific patch type that excludes `id`, indexed access, `Pick`, `Omit`, `Partial`, a mapped handler type, and a small conditional type using `infer`.

Run:

    ./verify.sh

The verifier installs only from the frozen offline lock, asserts TypeScript 7.0.2, runs strict type checking, emits JavaScript, and compares exact output. The declared Node 24.x engine is not verified when this command runs on another host version.
