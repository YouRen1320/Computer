# Event loop lab

Write the baseline queue trace before running `./verify.sh`. The verifier then launches four isolated expected-failure scripts:

- `PROMISE_AS_SYNC_VALUE`
- `MISSING_AWAIT_ORDER`
- `ASYNC_ERROR_BOUNDARY_LOST`
- `MICROTASK_ORDER_MISREAD`

Repair only after identifying the first trace/type/catch difference. No fault depends on exact timer duration or an ambient unhandled rejection.
