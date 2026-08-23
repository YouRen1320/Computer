# Modeling and narrowing exercise

The starter is intentionally red. Complete both TODOs without `any`, non-null assertions, or `as WorkOrder`:

1. Make `isWorkOrder` reject null, arrays, inherited/missing fields, empty ids, and unsupported priorities while accepting the valid fixture.
2. Handle the `cancelled` state so the `never` boundary is genuinely exhaustive.

Run:

    ./verify.sh

Only the byte-identical registered starter exits 41 with `EXPECTED_RED` and TS2322. A correct implementation exits 0 with `EXERCISE_GREEN`; partial changes, unknown failures, and infrastructure failures exit 43. Once compilation succeeds, the runtime oracle still requires the guard matrix and exact output.
