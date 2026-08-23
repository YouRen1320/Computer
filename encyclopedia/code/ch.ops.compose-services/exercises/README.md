# Compose policy exercise

Edit `audit.py`. The unchanged starter must return exit 41 with `EXPECTED_RED`;
once both unsafe and safe topology tests pass, the same `verify.sh` returns 0
with `EXERCISE_GREEN`. Any changed-but-still-failing or infrastructure shape
returns 43. This static exercise does not prove a Docker daemon cold start.
