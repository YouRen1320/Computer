# Browser performance diagnostic lab

The verifier first runs a green baseline, then confirms four injected failures:

- LAYOUT_THRASHING_FAULT
- LISTENER_LEAK_FAULT
- TIMER_RETENTION_FAULT
- PERFORMANCE_REGRESSION_FAULT

Run:

    ./verify.sh

Each counter is a deterministic ownership/scheduling model. After diagnosing it, repeat the same workload in the target browser and retain the Performance trace, heap snapshot comparison, source location, browser version, and accessibility checks.
