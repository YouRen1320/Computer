# frozen_string_literal: true

# This is the default lab: it is safe when Docker is absent or stopped and
# never contacts a registry. The opt-in shell lab exercises a real daemon.
load File.expand_path("../../../examples/encyclopedia/ch.foundations.docker-basics/verify.rb", __dir__)
