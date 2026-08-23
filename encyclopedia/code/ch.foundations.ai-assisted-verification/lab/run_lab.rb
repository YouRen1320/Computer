# frozen_string_literal: true

# Reuse the public deterministic verifier. It operates on in-memory worktrees,
# never calls a model, never opens the network, and needs no credentials.
load File.expand_path("../../../examples/encyclopedia/ch.foundations.ai-assisted-verification/verify.rb", __dir__)
