# Docker source-audit exercise

Edit `audit.py` to reject mutable bases, a root runtime user and secret-like
build-context files while admitting the safe fixture. `verify.sh` returns 41
only for the byte-exact registered starter, 0 for a completed implementation,
and 43 for partial, unknown or infrastructure failure. It is a static source
oracle, not a real image build or runtime proof.
