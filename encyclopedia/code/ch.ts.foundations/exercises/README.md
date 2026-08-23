# TypeScript foundations public exercise

The initial verifier must fail with UNSAFE_OPTIONAL_ACCESS_EXERCISE. In src/exercise.ts, replace the direct optional-property read with an explicit missing-assignee policy. Keep both assigned and unassigned runtime cases.

Run:

    ./verify.sh

A non-null assertion is not a solution: it can make noEmit pass while the unassigned runtime case still fails.
