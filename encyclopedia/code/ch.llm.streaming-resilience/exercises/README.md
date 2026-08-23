# Streaming resilience exercise

Edit `exercise.py` so terminal events, partial output, proposed tool calls,
cancellation and bounded/classified retry remain distinct. No side effect is
executed inside a replayable stream. The same verifier returns 41 only for the
exact starter, 0 for completion and 43 for partial/unknown/infrastructure.
