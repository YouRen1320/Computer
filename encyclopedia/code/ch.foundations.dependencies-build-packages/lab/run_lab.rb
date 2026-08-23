# frozen_string_literal: true

# The lab delegates to the public verifier so the same oracles are reused
# without mutating the learner's global package caches or tool configuration.
load File.expand_path("../../../examples/encyclopedia/ch.foundations.dependencies-build-packages/verify.rb", __dir__)
