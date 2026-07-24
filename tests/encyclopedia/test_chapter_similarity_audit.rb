# frozen_string_literal: true

require "json"
require "minitest/autorun"
require "open3"
require "pathname"
require "tmpdir"

class ChapterSimilarityAuditTest < Minitest::Test
  ROOT = Pathname(__dir__).join("../..").expand_path
  SCRIPT = ROOT.join("scripts/audit-chapter-similarity.py")

  def test_distinct_chapters_with_direct_sources_pass_and_output_is_deterministic
    with_fixture do |root|
      write_chapter(root, "ch.fixture.alpha", distinct_prose("甲乙丙丁戊己庚辛壬癸", "https://example.test/alpha"))
      write_chapter(root, "ch.fixture.beta", distinct_prose("天地玄黄宇宙洪荒日月盈昃", "https://example.test/beta"))
      write_chapter(root, "ch.fixture.gamma", distinct_prose("春夏秋冬东南西北山川湖海", "https://example.test/gamma"))

      first = root.join("first.json")
      second = root.join("second.json")
      first_result = run_audit(root, "--output", first.to_s)
      second_result = run_audit(root, "--output", second.to_s)
      report = JSON.parse(first.read)

      assert first_result[:status].success?, first_result[:stderr]
      assert second_result[:status].success?, second_result[:stderr]
      assert_equal first.binread, second.binread
      assert_equal "passed", report.fetch("status")
      assert_equal 3, report.dig("summary", "chapter_count")
      assert_equal 3, report.dig("summary", "evaluated_pair_count")
      assert_equal 3, report.dig("summary", "source_covered_chapter_count")
      assert_equal 0, report.dig("summary", "similarity_violation_count")
      assert_equal 3, report.fetch("pairs").length
      assert report.fetch("pairs").all? { |pair| pair.fetch("threshold_violation") == false }
    end
  end

  def test_exact_duplicate_fails_with_exact_jaccard_and_both_containments
    with_fixture do |root|
      shared = ("这是一段应被逐字符比较的原创正文用于确认完整集合交集而不是抽样估算。" * 20)
      write_chapter(root, "ch.fixture.alpha", "#{shared}\n\n来源：https://example.test/alpha\n")
      write_chapter(root, "ch.fixture.beta", "#{shared}\n\n来源：https://example.test/beta\n")

      result = run_audit(root)
      report = JSON.parse(result[:stdout])
      pair = report.fetch("pairs").fetch(0)

      assert_equal 1, result[:status].exitstatus
      assert_equal "failed", report.fetch("status")
      assert_equal 1, report.dig("summary", "similarity_violation_count")
      assert_equal pair.fetch("jaccard").fetch("denominator"), pair.fetch("jaccard").fetch("numerator")
      assert_equal 1.0, pair.fetch("jaccard").fetch("decimal")
      assert_equal 1.0, pair.fetch("containment_a_in_b").fetch("decimal")
      assert_equal 1.0, pair.fetch("containment_b_in_a").fetch("decimal")
      assert_equal %w[jaccard containment_a_in_b containment_b_in_a], pair.fetch("threshold_reasons")
    end
  end

  def test_template_lists_tables_generated_prerequisites_and_fences_are_not_compared
    with_fixture do |root|
      template = <<~MARKDOWN
        <!-- BEGIN GENERATED LEARNING PREREQUISITES -->
        ## 学习前检查
        - [重复先修](https://example.test/generated)
        <!-- END GENERATED LEARNING PREREQUISITES -->

        ```text
        #{"相同代码围栏内容" * 80}
        ```

        - #{"相同模板列表内容" * 80}

        | 列一 | 列二 |
        | --- | --- |
        | #{"相同表格内容" * 80} | value |
      MARKDOWN
      alpha = "#{template}\n#{"甲类正文只讨论完全不同的领域边界" * 30}\n来源：https://example.test/alpha\n"
      beta = "#{template}\n#{"乙类说明聚焦另一套互不相同的概念" * 30}\n来源：https://example.test/beta\n"
      write_chapter(root, "ch.fixture.alpha", alpha)
      write_chapter(root, "ch.fixture.beta", beta)

      result = run_audit(root)
      report = JSON.parse(result[:stdout])
      pair = report.fetch("pairs").fetch(0)

      assert result[:status].success?, result[:stderr]
      assert_equal 0, pair.fetch("intersection_shingle_count")
      assert_equal 0.0, pair.fetch("jaccard").fetch("decimal")
    end
  end

  def test_https_only_inside_a_fence_does_not_satisfy_source_coverage
    with_fixture do |root|
      write_chapter(root, "ch.fixture.alpha", <<~MARKDOWN)
        这段正文足够长，可以生成七字符切片，但没有直接来源。

        <!-- BEGIN GENERATED LEARNING PREREQUISITES -->
        - https://example.test/generated-prerequisite-is-not-a-source
        <!-- END GENERATED LEARNING PREREQUISITES -->

        ```text
        https://example.test/not-a-source
        ```

        <!-- https://example.test/hidden-comment-is-not-a-source -->
      MARKDOWN

      result = run_audit(root)
      report = JSON.parse(result[:stdout])

      assert_equal 1, result[:status].exitstatus
      assert_equal "failed", report.fetch("status")
      assert_equal ["ch.fixture.alpha"], report.fetch("missing_source_chapter_ids")
      assert_equal 1, report.dig("summary", "missing_source_chapter_count")
      assert report.fetch("failures").any? { |failure| failure.include?("no direct HTTPS source") }
    end
  end

  private

  def with_fixture
    Dir.mktmpdir("chapter-similarity-audit-") do |directory|
      yield Pathname(directory).realpath
    end
  end

  def write_chapter(root, chapter_id, body)
    directory = root.join("book/volume-00-fixture/chapters")
    directory.mkpath
    path = directory.join("#{chapter_id}.md")
    path.write(<<~MARKDOWN)
      ---
      schema_version: 2
      id: #{chapter_id}
      title: fixture
      ---
      # Fixture title

      #{body}
    MARKDOWN
  end

  def distinct_prose(sequence, source)
    "#{sequence * 30}\n\n来源：#{source}\n"
  end

  def run_audit(root, *arguments)
    stdout, stderr, status = Open3.capture3(
      { "PYTHONHASHSEED" => "0" },
      "python3",
      SCRIPT.to_s,
      "--root",
      root.to_s,
      *arguments
    )
    { stdout: stdout, stderr: stderr, status: status }
  end
end
