# Local LangGraph fixture

This graph uses the installed LangGraph StateGraph, interrupt, Command and
InMemorySaver APIs. The “Java authority” is an in-memory fixture with an
idempotency ledger. It proves replay behavior in one process; it is not a durable
database, distributed transaction, production checkpointer or real Java call.
