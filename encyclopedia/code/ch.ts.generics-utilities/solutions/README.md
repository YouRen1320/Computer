# Private solution: generics and utilities

The solution introduces `K extends keyof T`, returns `T[K]`, and keeps the WorkOrder patch concrete. The chapter lab and public exercise retain the independent invalid-key fixtures; this private directory proves the completed positive contract and runtime oracle.

Run:

    ./verify.sh
