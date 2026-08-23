"""Public exercise: compare immutable digests, not human-readable tags."""


def is_same_artifact(test: dict[str, str], production: dict[str, str]) -> bool:
    # Deliberately wrong: the same tag can move to different content.
    return test.get("tag") == production.get("tag")
