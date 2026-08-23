# Generics and utilities exercise

The starter is intentionally red with TS7053 because a plain `string` key does not preserve any relationship to `T`.

Complete `selectField` so that:

1. the key is constrained to `keyof T`;
2. the return type is the corresponding indexed access `T[K]`;
3. no `any` or caller-side assertion is required;
4. `faults/invalid-key.ts` still fails with TS2345;
5. the exact runtime output passes.

Run `./verify.sh`. Only the byte-identical registered starter exits 41 with `EXPECTED_RED`; a correct implementation exits 0 with `EXERCISE_GREEN` after checking both the positive program and the independent negative key fixture. Partial changes, unknown failures, and infrastructure failures exit 43. The inner TypeScript command may use its own diagnostic exit, but that is not the public wrapper contract.
