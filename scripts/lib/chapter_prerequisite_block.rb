# frozen_string_literal: true

require "pathname"

# Renders the canonical, reader-facing prerequisite block that appears
# immediately after a chapter's H1. The catalog remains the only source of
# prerequisite IDs and rationales; chapter prose receives a synchronized view.
module ChapterPrerequisiteBlock
  BEGIN_MARKER = "<!-- BEGIN GENERATED LEARNING PREREQUISITES -->"
  END_MARKER = "<!-- END GENERATED LEARNING PREREQUISITES -->"
  HEADING = "## 学习前检查"
  ROOT_MESSAGE = "本章无编程先修。零基础读者可以直接从本章开始，并按正文中的预测、操作、验证和复述步骤建立第一份学习证据。"
  INTRODUCTION = "以下章节是本章的硬前置。开始前，请先完成并验证对应能力："

  class ContractError < StandardError; end

  module_function

  def render(chapter:, chapters_by_id:)
    prerequisites = chapter.fetch("prerequisites")
    rationales = chapter.fetch("prerequisite_rationales")
    unless prerequisites.is_a?(Array) && prerequisites.all? { |id| id.is_a?(String) }
      raise ContractError, "#{chapter.fetch('id')} prerequisites must be a string array"
    end
    unless rationales.is_a?(Hash) && rationales.keys.sort == prerequisites.sort
      raise ContractError, "#{chapter.fetch('id')} prerequisite rationale keys must exactly match prerequisites"
    end

    lines = [BEGIN_MARKER, HEADING, ""]
    if prerequisites.empty?
      lines << ROOT_MESSAGE
    else
      lines << INTRODUCTION << ""
      prerequisites.each do |dependency_id|
        dependency = chapters_by_id[dependency_id]
        raise ContractError, "#{chapter.fetch('id')} references unknown prerequisite #{dependency_id}" unless dependency

        rationale = rationales.fetch(dependency_id)
        reason = rationale.is_a?(Hash) ? rationale["reason"] : nil
        unless reason.is_a?(String) && !reason.strip.empty? && !reason.include?("\n")
          raise ContractError, "#{chapter.fetch('id')} prerequisite #{dependency_id} must have a one-line reason"
        end

        link = relative_link(chapter.fetch("path"), dependency.fetch("path"))
        lines << "- [《#{dependency.fetch('title')}》](#{link})：#{reason.strip}"
      end
    end
    lines << END_MARKER
    lines.join("\n")
  end

  def synchronize(contents, chapter:, chapters_by_id:)
    marker_counts = [contents.scan(BEGIN_MARKER).length, contents.scan(END_MARKER).length]
    unless marker_counts[0] == marker_counts[1] && marker_counts[0] <= 1
      raise ContractError, "#{chapter.fetch('id')} has malformed or duplicate learning prerequisite markers"
    end

    without_block = contents.dup
    if marker_counts[0] == 1
      pattern = /^#{Regexp.escape(BEGIN_MARKER)}\n.*?^#{Regexp.escape(END_MARKER)}(?:\n|\z)/m
      removed = without_block.sub!(pattern, "")
      raise ContractError, "#{chapter.fetch('id')} learning prerequisite block is not well formed" unless removed
    end

    front_matter = without_block.match(/\A---\s*\n.*?\n---\s*\n/m)
    raise ContractError, "#{chapter.fetch('id')} is missing YAML front matter" unless front_matter

    prefix = without_block[0...front_matter.end(0)]
    body = without_block[front_matter.end(0)..].to_s
    first_nonblank = body.index(/\S/)
    raise ContractError, "#{chapter.fetch('id')} is missing its H1" unless first_nonblank

    h1 = body.match(/\G# ([^\n]+)[ \t]*(?:\n|\z)/, first_nonblank)
    unless h1 && h1[1] == chapter.fetch("title")
      raise ContractError, "#{chapter.fetch('id')} first body heading must be # #{chapter.fetch('title')}"
    end

    before = body[0...h1.end(0)]
    after = body[h1.end(0)..].to_s.sub(/\A(?:[ \t]*\n)+/, "")
    synchronized_body = "#{before}\n#{render(chapter: chapter, chapters_by_id: chapters_by_id)}\n"
    synchronized_body = "#{synchronized_body}\n#{after}" unless after.empty?
    "#{prefix}#{synchronized_body}"
  end

  def relative_link(from_path, to_path)
    source_directory = Pathname(from_path).dirname
    target = Pathname(to_path)
    relative = target.relative_path_from(source_directory).to_s
    unless relative.match?(%r{\A(?:\.\./)*[a-zA-Z0-9._/-]+\.md\z})
      raise ContractError, "unsafe prerequisite link from #{from_path} to #{to_path}"
    end

    relative
  end
end
