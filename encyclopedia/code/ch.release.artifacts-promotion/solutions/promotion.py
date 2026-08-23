"""Reference solution: immutable digest defines artifact identity."""

import re


DIGEST = re.compile(r"^sha256:[0-9a-f]{64}$")


def is_same_artifact(test: dict[str, str], production: dict[str, str]) -> bool:
    left = test.get("digest", "")
    right = production.get("digest", "")
    return bool(DIGEST.fullmatch(left)) and left == right
