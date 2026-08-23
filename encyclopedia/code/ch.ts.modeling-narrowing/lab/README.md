# Modeling and narrowing diagnostic lab

The green verifier first proves a strict baseline and runtime guard matrix. It then requires three injected faults to surface for their intended reasons:

- `NONEXHAUSTIVE_STATE_FAULT`: adding `cancelled` without a branch must produce TS2322 at the `never` boundary.
- `INVALID_GUARD_RUNTIME_FAULT`: an over-promising predicate compiles but accepts a malformed payload and fails at runtime.
- `UNSAFE_ANY_RUNTIME_FAULT`: `any` bypasses property checks and moves the error to runtime.

Run:

    ./verify.sh

The fault fixtures are outside the baseline `tsconfig.json` include set. Diagnose from the first trustworthy compiler or runtime marker, repair the corresponding model in your own copy, and rerun the same command.
