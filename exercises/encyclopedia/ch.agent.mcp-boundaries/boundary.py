def backend_is_allowed(backend: str) -> bool:
    # TODO: the MCP adapter may call the Java authority, never its database directly.
    return backend in {"java_authoritative_api", "postgres_direct"}
