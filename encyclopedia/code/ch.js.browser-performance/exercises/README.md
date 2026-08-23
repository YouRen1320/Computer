# Browser performance public exercise

The initial verifier must fail with PERFORMANCE_BUDGET_EXERCISE. In src/exercise.mjs, replace the interleaved scheduling in scheduleRows with a read phase followed by a write phase. Keep row order, accessible names, listener cleanup, and timer cleanup unchanged.

Run:

    ./verify.sh

Completion here proves the deterministic model budget only. Record a target-browser trace and heap comparison before claiming the chapter performance oracle.
