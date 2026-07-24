#!/usr/bin/env ruby
# frozen_string_literal: true

require "optparse"
require "pathname"
require "yaml"
require_relative "lib/chapter_prerequisite_block"

USAGE = "Usage: ruby scripts/sync-chapter-prerequisites.rb (--check|--write)".freeze
MODES = { "--check" => :check, "--write" => :write }.freeze

unless ARGV.length == 1 && MODES.key?(ARGV.first)
  warn USAGE
  exit 2
end

root = Pathname(File.expand_path("..", __dir__))
catalog_path = root.join("curriculum/catalog.yml")

begin
  catalog = YAML.safe_load(File.read(catalog_path, encoding: "UTF-8"), aliases: false)
  raise "curriculum/catalog.yml root must be a mapping" unless catalog.is_a?(Hash)

  chapters = catalog.fetch("chapters")
  raise "curriculum/catalog.yml chapters must be an array" unless chapters.is_a?(Array)

  chapters_by_id = chapters.each_with_object({}) do |chapter, memo|
    raise "catalog chapter must be a mapping" unless chapter.is_a?(Hash)

    id = chapter.fetch("id")
    raise "duplicate chapter id #{id}" if memo.key?(id)

    memo[id] = chapter
  end

  changed = []
  chapters.each do |chapter|
    relative = chapter.fetch("path")
    path = root.join(relative)
    raise "chapter path escapes repository: #{relative}" unless path.expand_path.to_s.start_with?("#{root}/")
    raise "chapter path is not a regular file: #{relative}" unless path.file? && !path.symlink?

    current = File.read(path, encoding: "UTF-8")
    expected = ChapterPrerequisiteBlock.synchronize(
      current,
      chapter: chapter,
      chapters_by_id: chapters_by_id
    )
    next if current == expected

    changed << relative
    File.binwrite(path, expected) if MODES.fetch(ARGV.first) == :write
  end

  if MODES.fetch(ARGV.first) == :check && !changed.empty?
    warn "CHAPTER PREREQUISITE CHECK FAILED: #{changed.length} chapter(s) are out of sync"
    changed.each { |relative| warn "- #{relative}" }
    exit 1
  end

  mode = MODES.fetch(ARGV.first)
  roots = chapters.count { |chapter| chapter.fetch("prerequisites").empty? }
  edges = chapters.sum { |chapter| chapter.fetch("prerequisites").length }
  puts "CHAPTER PREREQUISITES #{mode.to_s.upcase} OK chapters=#{chapters.length} roots=#{roots} edges=#{edges} changed=#{changed.length}"
rescue StandardError => e
  warn "CHAPTER PREREQUISITES FAILED: #{e.message}"
  exit 1
end
