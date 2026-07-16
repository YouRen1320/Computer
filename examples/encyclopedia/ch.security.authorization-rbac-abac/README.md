# FactoryCare authorization-policy example

This offline JDK 25 example combines role-derived permissions with object attributes. It evaluates synthetic FactoryCare work-order `READ`, `ASSIGN`, and `CLOSE` decisions for owner/reporter, assigned technician, dispatcher, unknown role, and unknown action. A direct service call uses the same policy, demonstrating that URL protection alone is insufficient.

Run `./verify.sh`. No Spring context, HTTP server, database, tenant, account, or token is created. Passing proves only the closed policy model; production must also verify FilterChain, method-security proxy, transaction, current membership, and scoped database behavior.
