# Tool-calling boundary exercise

Edit `exercise.py` so a static allowlist, strict schema, trusted principal and
resource authorization run before handlers. Close operations require an exact,
unexpired approval bound to principal/tool/payload/resource-version/purpose;
idempotent replays return the original receipt and changed payloads conflict.
Exit states are exact starter 41, completed 0 and all other failures 43.
