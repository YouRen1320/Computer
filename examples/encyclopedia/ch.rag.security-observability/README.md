# Controlled security fixture

The corpus, principals, generator and trace sink are local fixtures. No PostgreSQL,
pgvector, model provider, identity service or telemetry backend is contacted. The
tests prove pre-context filtering and redaction in this implementation only; they
do not certify a deployed multi-tenant system.
