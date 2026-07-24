#!/usr/bin/env ruby
# frozen_string_literal: true

require File.expand_path("../verification/lib/application", __dir__)

exit Verification::Application.run(ARGV)
