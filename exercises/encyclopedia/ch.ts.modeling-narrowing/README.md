# Modeling and narrowing exercise

The starter is intentionally red. Complete both TODOs without `any`, non-null assertions, or `as WorkOrder`:

1. Make `isWorkOrder` reject null, arrays, inherited/missing fields, empty ids, and unsupported priorities while accepting the valid fixture.
2. Handle the `cancelled` state so the `never` boundary is genuinely exhaustive.

Run:

    ./verify.sh

Initially the verifier exits 1 with `MODELING_NARROWING_EXERCISE_RED` and TS2322. Once compilation succeeds, its runtime oracle still requires the guard matrix and exact output.
