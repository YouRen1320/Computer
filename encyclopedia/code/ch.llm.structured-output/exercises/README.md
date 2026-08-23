# Structured-output exercise

Edit `exercise.py` to define a strict, versioned Pydantic response and parse via
runtime model validation. Missing/extra/unknown/coerced/invalid input must remain
an explicit validation error, never a silent HIGH-priority repair. The verifier
returns exact starter 41, completed 0, or partial/unknown/infrastructure 43.
