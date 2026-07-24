# frozen_string_literal: true

require "minitest/autorun"
require_relative "../../scripts/lib/chapter_prerequisite_block"

class ChapterPrerequisiteBlockTest < Minitest::Test
  def test_synchronize_is_idempotent_and_keeps_following_prose
    dependency = chapter(
      id: "ch.foundation.basics",
      title: "基础章",
      path: "book/volume-00-foundations/chapters/ch.foundation.basics.md"
    )
    current = chapter(
      id: "ch.application.topic",
      title: "应用章",
      path: "book/volume-01-application/chapters/ch.application.topic.md",
      prerequisites: [dependency.fetch("id")],
      rationales: {
        dependency.fetch("id") => { "reason" => "必须先能独立验证基础能力" }
      }
    )
    chapters = { dependency.fetch("id") => dependency, current.fetch("id") => current }
    source = "---\nid: ch.application.topic\n---\n# 应用章\n\n正文第一段。\n"

    once = ChapterPrerequisiteBlock.synchronize(source, chapter: current, chapters_by_id: chapters)
    twice = ChapterPrerequisiteBlock.synchronize(once, chapter: current, chapters_by_id: chapters)

    assert_equal once, twice
    assert_includes once, "[《基础章》](../../volume-00-foundations/chapters/ch.foundation.basics.md)：必须先能独立验证基础能力"
    assert once.index(ChapterPrerequisiteBlock::HEADING) < once.index("正文第一段。")
  end

  def test_root_chapter_gets_explicit_zero_base_message
    root = chapter(
      id: "ch.foundation.root",
      title: "起点章",
      path: "book/volume-00-foundations/chapters/ch.foundation.root.md"
    )
    source = "---\nid: ch.foundation.root\n---\n\n# 起点章\n\n正文。\n"

    rendered = ChapterPrerequisiteBlock.synchronize(
      source,
      chapter: root,
      chapters_by_id: { root.fetch("id") => root }
    )

    assert_includes rendered, ChapterPrerequisiteBlock::ROOT_MESSAGE
  end

  def test_duplicate_markers_are_rejected_instead_of_silently_collapsed
    root = chapter(
      id: "ch.foundation.root",
      title: "起点章",
      path: "book/volume-00-foundations/chapters/ch.foundation.root.md"
    )
    duplicated = <<~MARKDOWN
      ---
      id: ch.foundation.root
      ---
      # 起点章

      #{ChapterPrerequisiteBlock::BEGIN_MARKER}
      #{ChapterPrerequisiteBlock::END_MARKER}
      #{ChapterPrerequisiteBlock::BEGIN_MARKER}
      #{ChapterPrerequisiteBlock::END_MARKER}
    MARKDOWN

    error = assert_raises(ChapterPrerequisiteBlock::ContractError) do
      ChapterPrerequisiteBlock.synchronize(
        duplicated,
        chapter: root,
        chapters_by_id: { root.fetch("id") => root }
      )
    end
    assert_match(/malformed or duplicate/, error.message)
  end

  private

  def chapter(id:, title:, path:, prerequisites: [], rationales: {})
    {
      "id" => id,
      "title" => title,
      "path" => path,
      "prerequisites" => prerequisites,
      "prerequisite_rationales" => rationales
    }
  end
end
