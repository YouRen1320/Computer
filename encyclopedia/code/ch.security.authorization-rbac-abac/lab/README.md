# RBAC/ABAC enforcement fault lab

This offline JDK 25 lab evaluates a small FactoryCare work-order policy and injects seven bypasses: UI-only control, URL-only control, permission-only IDOR, unknown-role allow, unknown-action allow, allow-wins conflict, and trusting a client-supplied owner flag.

Run `./verify.sh`. The normal matrix must be green, and every faulty mode must expose its named oracle. This model does not start Spring, AOP, HTTP, a transaction, or a database; real T4 evidence must repeat the same failures through those boundaries.
