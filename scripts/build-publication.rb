#!/usr/bin/env ruby
# frozen_string_literal: true

ROOT = File.expand_path("..", __dir__)

require File.join(ROOT, "publication", "lib", "renderer")

begin
  unless ARGV.empty?
    warn "PUBLICATION BUILD FAILED: invalid command-line arguments"
    warn "Usage: ruby scripts/build-publication.rb"
    exit 2
  end

  result = Publication::Renderer.new(ROOT).build
  manifest = result.fetch("manifest")
  puts "PUBLICATION BUILD OK"
  puts "profile=#{manifest.fetch('profile_id')} outputs=#{manifest.fetch('output_count')} status=#{manifest.fetch('build_status')}"
rescue Publication::ContractError => e
  warn "PUBLICATION BUILD FAILED: #{e.diagnostic}"
  exit 1
rescue StandardError => e
  warn "PUBLICATION BUILD FAILED: [internal/E_UNEXPECTED] #{e.class}"
  exit 1
end
