# Generics and utilities exercise

The starter is intentionally red with TS7053 because a plain `string` key does not preserve any relationship to `T`.

Complete `selectField` so that:

1. the key is constrained to `keyof T`;
2. the return type is the corresponding indexed access `T[K]`;
3. no `any` or caller-side assertion is required;
4. `faults/invalid-key.ts` still fails with TS2345;
5. the exact runtime output passes.

Run `./verify.sh`. Initially it exits 1 with `GENERICS_UTILITIES_EXERCISE_RED`; after a correct implementation it checks both the positive program and the independent negative key fixture.
