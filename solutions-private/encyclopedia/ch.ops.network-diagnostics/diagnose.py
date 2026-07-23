"""Reference solution for dependency-ordered network diagnosis."""


def earliest_failed_layer(probes: dict[str, bool]) -> str:
    for layer in ("dns", "tcp", "tls", "http"):
        if not probes[layer]:
            return layer
    return "none"
