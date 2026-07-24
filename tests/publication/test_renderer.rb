# frozen_string_literal: true

require "digest"
require "json"

require_relative "test_helper"

class PublicationRendererTest < Minitest::Test
  include PublicationFixture

  class FakeCommandRunner
    attr_reader :calls

    def initialize(fail_match: nil, output_payload: nil, ast_payload: nil)
      @fail_match = fail_match
      @output_payload = output_payload
      @ast_payload = ast_payload
      @calls = []
    end

    def call(argv, chdir:, env:)
      @calls << { argv: argv.dup, chdir: chdir, env: env.dup }
      return ["", "injected failure", 17] if @fail_match && argv.join(" ").include?(@fail_match)

      if version_command?(argv)
        return [version_output(argv), "", 0]
      end

      if argv.first == "pandoc" && option_value(argv, "--to") == "json"
        write_output(argv, @ast_payload || CanonicalFixture.document)
      elsif argv.first == "pandoc"
        payload = if option_value(argv, "--to") == "epub3"
                    "PK\x03\x04#{@output_payload || 'fixture epub'}\n".b
                  else
                    valid_html(@output_payload || "fixture")
                  end
        write_output(argv, payload)
      elsif deterministic_weasyprint_command?(argv)
        payload = "%PDF-1.7\n#{@output_payload || 'fixture'}\n%%EOF\n"
        FileUtils.mkdir_p(File.dirname(argv.last))
        File.binwrite(argv.last, payload)
      else
        raise "unexpected fixture command #{argv.first}"
      end
      ["", "", 0]
    end

    private

    def version_command?(argv)
      (argv.length == 2 && %w[--version -v].include?(argv.last))
    end

    def version_output(argv)
      case argv.first
      when "pandoc" then "pandoc 3.9.0.2\n"
      when "dpy" then "Python 3.14.3\n"
      when "ruby" then "ruby 2.6.10p210 (fixture)\n"
      when "weasyprint" then "WeasyPrint version 68.1\n"
      else raise "unexpected version command"
      end
    end

    def deterministic_weasyprint_command?(argv)
      argv.first == "dpy" && argv[1]&.end_with?("publication/lib/deterministic_weasyprint.py")
    end

    def option_value(argv, option)
      index = argv.index(option)
      return argv[index + 1] if index

      prefixed = argv.find { |argument| argument.start_with?("#{option}=") }
      prefixed && prefixed.split("=", 2).last
    end

    def write_output(argv, bytes)
      path = option_value(argv, "--output")
      raise "fixture command has no output" unless path

      FileUtils.mkdir_p(File.dirname(path))
      File.binwrite(path, bytes)
    end

    def valid_html(body)
      <<~HTML
        <!doctype html>
        <html lang="zh-CN">
        <head>
          <meta name="robots" content="noindex,nofollow">
          <title>fixture</title>
        </head>
        <body>
          <a class="skip-link" href="#main-content">跳到正文</a>
          <header>内部审查预览，尚未完成正式评审，不得公开发布</header>
          <main id="main-content">#{body}</main>
          <footer>fixture</footer>
        </body>
        </html>
      HTML
    end
  end

  module CanonicalFixture
    module_function

    TITLES = [
      "JDK、JVM、源码、class 文件、编译与运行",
      "注释、标识符、字面量、语句、代码块、class、main 与 package",
      "值、变量、基本类型、String、作用域与基本输出",
      "运算符、表达式、类型转换、溢出与整数分金额"
    ].freeze

    def document
      blocks = TITLES.each_with_index.flat_map do |title, index|
        [
          { "t" => "Header", "c" => [1, ["chapter-#{index}", [], []], [{ "t" => "Str", "c" => title }]] },
          { "t" => "Para", "c" => [{ "t" => "Str", "c" => "fixture #{index}" }] }
        ]
      end
      JSON.generate("pandoc-api-version" => [1, 23, 1, 1], "meta" => {}, "blocks" => blocks)
    end
  end

  def test_rejects_digest_drift_before_any_tool_or_render_command
    with_renderer_fixture do |root, _plan|
      chapter = root.join("book/volume-01-java-language/chapters/ch.java.platform-toolchain.md")
      original = File.binread(chapter)
      changed = original.sub("JDK", "JDX")
      assert_equal original.bytesize, changed.bytesize
      File.binwrite(chapter, changed)
      runner = FakeCommandRunner.new

      assert_contract_code("E_INPUT_DIGEST") do
        Publication::Renderer.new(root.to_s, command_runner: runner).build
      end
      assert_empty runner.calls
    end
  end

  def test_rejects_renderer_stylesheet_drift_before_any_tool_command
    with_renderer_fixture do |root, _plan|
      stylesheet = root.join("publication/styles/p3-gold-screen.css")
      original = File.binread(stylesheet)
      changed = original.sub("body", "bodi")
      assert_equal original.bytesize, changed.bytesize
      File.binwrite(stylesheet, changed)
      runner = FakeCommandRunner.new

      assert_contract_code("E_INPUT_DIGEST") do
        Publication::Renderer.new(root.to_s, command_runner: runner).build
      end
      assert_empty runner.calls
    end
  end

  def test_command_failure_leaves_the_previous_profile_tree_untouched
    with_renderer_fixture do |root, plan_bytes|
      marker = root.join("build/publication/p3-gold/previous-output.txt")
      File.binwrite(marker, "previous\n")
      runner = FakeCommandRunner.new(fail_match: "--to=html5")

      assert_contract_code("E_COMMAND_FAILED") do
        Publication::Renderer.new(root.to_s, command_runner: runner).build
      end
      assert_equal "previous\n", File.binread(marker)
      assert_equal plan_bytes, File.binread(root.join("build/publication/p3-gold/publication-plan.json"))
      assert_empty Dir.glob(root.join("build/publication/.p3-gold.render-stage-*").to_s)
    end
  end

  def test_rejects_private_markers_in_generated_outputs_before_promotion
    with_renderer_fixture do |root, _plan_bytes|
      marker = root.join("build/publication/p3-gold/previous-output.txt")
      File.binwrite(marker, "previous\n")
      runner = FakeCommandRunner.new(output_payload: "solutions-private/fixture-answer.md\n")

      assert_contract_code("E_OUTPUT_LEAK") do
        Publication::Renderer.new(root.to_s, command_runner: runner).build
      end
      assert_equal "previous\n", File.binread(marker)
    end
  end

  def test_rejects_remote_images_before_any_format_writer_runs
    with_renderer_fixture do |root, _plan_bytes|
      document = JSON.parse(CanonicalFixture.document)
      document.fetch("blocks").insert(
        1,
        {
          "t" => "Para",
          "c" => [
            {
              "t" => "Image",
              "c" => [["", [], []], [{ "t" => "Str", "c" => "remote" }], ["https://example.test/image.png", ""]]
            }
          ]
        }
      )
      runner = FakeCommandRunner.new(ast_payload: JSON.generate(document))

      assert_contract_code("E_REMOTE_RESOURCE") do
        Publication::Renderer.new(root.to_s, command_runner: runner).build
      end
      render_calls = runner.calls.map { |call| call.fetch(:argv) }.select do |argv|
        argv.first == "pandoc" && !argv.include?("--version") && option_value(argv, "--to") != "json"
      end
      assert_empty render_calls
    end
  end

  def test_rejects_local_images_and_executable_raw_html
    [
      {
        expected: "E_LOCAL_RESOURCE",
        block: {
          "t" => "Para",
          "c" => [
            {
              "t" => "Image",
              "c" => [["", [], []], [{ "t" => "Str", "c" => "local" }], ["../../../unplanned.png", ""]]
            }
          ]
        }
      },
      {
        expected: "E_UNSAFE_RAW_HTML",
        block: { "t" => "RawBlock", "c" => ["html", "<script>alert('fixture')</script>"] }
      }
    ].each do |fixture|
      with_renderer_fixture do |root, _plan_bytes|
        document = JSON.parse(CanonicalFixture.document)
        document.fetch("blocks").insert(1, fixture.fetch(:block))
        runner = FakeCommandRunner.new(ast_payload: JSON.generate(document))

        assert_contract_code(fixture.fetch(:expected)) do
          Publication::Renderer.new(root.to_s, command_runner: runner).build
        end
      end
    end
  end

  def test_canonical_ast_embeds_declared_artifacts_and_rewrites_local_links
    with_renderer_fixture do |root, _plan_bytes|
      result = Publication::Renderer.new(root.to_s, command_runner: FakeCommandRunner.new).build
      ast_path = root.join("build/publication/p3-gold/ast/book.json")
      ast = JSON.parse(File.binread(ast_path))
      serialized = JSON.generate(ast)

      assert_includes serialized, "公开工件附录"
      assert_includes serialized, "examples/encyclopedia/ch.java.platform-toolchain/README.md"
      assert_includes serialized, "artifact-ch.java.platform-toolchain-example-readme"
      assert_equal 54, serialized.scan(/data-source-path/).length
      refute_includes serialized, "../../../examples/encyclopedia"
      assert_equal "succeeded", result.fetch("manifest").fetch("build_status")
    end
  end

  def test_promotion_failure_restores_the_previous_profile_tree
    with_renderer_fixture do |root, plan_bytes|
      marker = root.join("build/publication/p3-gold/previous-output.txt")
      File.binwrite(marker, "previous\n")
      rename_count = 0
      renamer = lambda do |source, destination|
        rename_count += 1
        raise IOError, "injected promotion failure" if rename_count == 2

        File.rename(source, destination)
      end

      assert_contract_code("E_ATOMIC_PROMOTION") do
        Publication::Renderer.new(root.to_s, command_runner: FakeCommandRunner.new, renamer: renamer).build
      end
      assert_equal "previous\n", File.binread(marker)
      assert_equal plan_bytes, File.binread(root.join("build/publication/p3-gold/publication-plan.json"))
      assert_empty Dir.glob(root.join("build/publication/.p3-gold.render-*").to_s)
    end
  end

  def test_manifest_matches_schema_and_records_candidate_boundaries
    with_renderer_fixture do |root, _plan_bytes|
      runner = FakeCommandRunner.new
      result = Publication::Renderer.new(root.to_s, command_runner: runner).build
      manifest = result.fetch("manifest")

      Publication::ContractLoader.new(root.to_s).validate_value!(
        manifest,
        Publication::OUTPUT_SCHEMA,
        "fixture output manifest"
      )
      assert_equal 9, manifest.fetch("output_count")
      assert_equal "not-os-enforced", manifest.fetch("environment").fetch("network_isolation")
      candidates = manifest.fetch("outputs").select { |output| output.fetch("distribution") == "internal-review-candidate" }
      assert_equal 7, candidates.length
      assert_equal ["pdf-candidate"], candidates.select { |output| output.fetch("format") == "pdf" }.map { |output| output.fetch("kind") }
      refute_includes JSON.generate(manifest), "conformant"

      pandoc_calls = runner.calls.map { |call| call.fetch(:argv) }.select { |argv| argv.first == "pandoc" }
      parse_calls = pandoc_calls.select { |argv| option_value(argv, "--to") == "json" }
      assert_equal 1, parse_calls.length
      assert parse_calls.first.any? { |argument| argument.end_with?(".md") }
      pandoc_calls.reject { |argv| argv.equal?(parse_calls.first) }.each do |argv|
        refute argv.any? { |argument| argument.end_with?(".md") }, argv.inspect
      end
      weasy = runner.calls.map { |call| call.fetch(:argv) }.find do |argv|
        argv.first == "dpy" && argv[1]&.end_with?("publication/lib/deterministic_weasyprint.py")
      end
      assert_equal "dpy", weasy.first
      assert weasy[-2].end_with?("intermediate/print/book.html")
    end
  end

  def test_two_same_machine_builds_are_byte_identical_with_fixed_runner
    with_renderer_fixture do |root, _plan_bytes|
      Publication::Renderer.new(root.to_s, command_runner: FakeCommandRunner.new).build
      first = tree_digests(root.join("build/publication/p3-gold"))
      Publication::Renderer.new(root.to_s, command_runner: FakeCommandRunner.new).build
      second = tree_digests(root.join("build/publication/p3-gold"))

      assert_equal first, second
    end
  end

  private

  def with_renderer_fixture
    with_publication_fixture do |root|
      # Another verification process may leave ignored build/target trees in
      # the developer checkout. Fixtures model the declared source inventory,
      # so remove only those copied generated components inside the temp tree.
      %w[examples labs exercises].product(Publication::P3_GOLD_IDS).each do |kind, id|
        owned_root = root.join(kind, "encyclopedia", id)
        generated = Dir.glob(owned_root.join("**/*").to_s, File::FNM_DOTMATCH).select do |path|
          File.directory?(path) && Publication::PlanBuilder::GENERATED_COMPONENTS.include?(File.basename(path))
        end
        generated.sort_by { |path| -path.length }.each { |path| FileUtils.rm_rf(path) }
      end
      builder = fixture_builder(root)
      plan = builder.build
      plan_bytes = builder.render(plan).b
      Publication::AtomicTreeWriter.new(root.to_s).write(Publication::Renderer::PROFILE_ID, plan_bytes)
      yield root, plan_bytes
    end
  end

  def tree_digests(directory)
    Dir.glob(directory.join("**/*").to_s).sort.each_with_object({}) do |path, memo|
      next unless File.file?(path)

      relative = path.delete_prefix(directory.to_s + File::SEPARATOR)
      memo[relative] = Digest::SHA256.file(path).hexdigest
    end
  end

  def option_value(argv, option)
    index = argv.index(option)
    return argv[index + 1] if index

    prefixed = argv.find { |argument| argument.start_with?("#{option}=") }
    prefixed && prefixed.split("=", 2).last
  end
end
