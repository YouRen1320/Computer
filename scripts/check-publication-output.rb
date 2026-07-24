#!/usr/bin/env ruby
# frozen_string_literal: true

ROOT = File.expand_path("..", __dir__)

require File.join(ROOT, "publication", "lib", "renderer")

begin
  unless ARGV.empty?
    warn "PUBLICATION OUTPUT CHECK FAILED: invalid command-line arguments"
    warn "Usage: ruby scripts/check-publication-output.rb"
    exit 2
  end

  result = Publication::Renderer.new(ROOT).check
  puts "PUBLICATION OUTPUT CHECK OK"
  puts "profile=#{result.fetch('profile_id')} outputs=#{result.fetch('output_count')} manifest_sha256=#{result.fetch('manifest_sha256')}"
rescue Publication::ContractError => e
  warn "PUBLICATION OUTPUT CHECK FAILED: #{e.diagnostic}"
  exit 1
rescue StandardError => e
  warn "PUBLICATION OUTPUT CHECK FAILED: [internal/E_UNEXPECTED] #{e.class}"
  exit 1
end
