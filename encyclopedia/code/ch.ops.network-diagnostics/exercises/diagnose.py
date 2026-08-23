"""Public exercise: return the earliest failed layer, not the loudest symptom."""


def earliest_failed_layer(probes: dict[str, bool]) -> str:
    # Deliberately wrong: this reverses the dependency path.
    for layer in ("http", "tls", "tcp", "dns"):
        if not probes[layer]:
            return layer
    return "none"
