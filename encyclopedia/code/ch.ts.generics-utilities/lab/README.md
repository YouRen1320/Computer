# Generics and utilities diagnostic lab

The green baseline proves exact selection and locked-id patch behavior. The verifier then requires four injected failures:

- `INVALID_KEY_FAULT` — TS2322 rejects a tuple element outside `keyof WorkOrder`.
- `GENERIC_CONSTRAINT_GAP_FAULT` — TS2339 exposes an implementation capability missing from the generic constraint.
- `DISTRIBUTIVE_CONDITIONAL_FAULT` — TS2322 shows that a naked type parameter distributed over a union.
- `OVERASSERTION_RUNTIME_FAULT` — a false `Pick` assertion compiles but returns a missing field.

It also requires `complexity-review.md`, which records the type-complexity ceiling and the local assertion boundary. Run `./verify.sh`, diagnose from the named first evidence, and rerun the same command after experimenting in a copy.
