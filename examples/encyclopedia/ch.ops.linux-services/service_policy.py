"""Linux permission calculations used by the chapter's controlled examples."""

from dataclasses import dataclass


READ = 4
WRITE = 2
EXECUTE = 1


@dataclass(frozen=True)
class Identity:
    user: str
    groups: frozenset[str]


@dataclass(frozen=True)
class FilePolicy:
    owner: str
    group: str
    mode: int


def selected_permission(identity: Identity, policy: FilePolicy) -> int:
    """Return the owner, group, or other octal digit selected by the kernel."""
    if identity.user == policy.owner:
        return (policy.mode >> 6) & 0b111
    if policy.group in identity.groups:
        return (policy.mode >> 3) & 0b111
    return policy.mode & 0b111


def may(identity: Identity, policy: FilePolicy, operation: str) -> bool:
    required = {"read": READ, "write": WRITE, "execute": EXECUTE}.get(operation)
    if required is None:
        raise ValueError(f"unknown operation: {operation}")
    return bool(selected_permission(identity, policy) & required)
