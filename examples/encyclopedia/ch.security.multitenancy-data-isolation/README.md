# Tenant-isolation example

This offline JDK 25 example models a trusted membership-derived tenant context, tenant-scoped list/read/write operations, tenant-aware cache keys, explicit task envelopes, and an explicit GLOBAL/TENANT catalog scope. Tenant A and B deliberately share a local resource ID.

Run `./verify.sh`. No Spring, MyBatis, SQL, PostgreSQL, Redis, queue, account, or token is used. Passing proves only the in-memory invariants; real evidence requires the target mappers, migrations, database, cache, and async executors.
