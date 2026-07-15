# frozen_string_literal: true

require "date"
require "digest"
require "fileutils"
require "json"
require "minitest/autorun"
require "open3"
require "pathname"
require "rbconfig"
require "tmpdir"
require "yaml"

class EncyclopediaSecurityTest < Minitest::Test
  ROOT = Pathname(__dir__).join("../..").expand_path.freeze
  FIXTURE_PATHS = %w[book curriculum schemas versions site scripts ASSESSMENTS.md PROGRESS.md].freeze
  GENERATED_NAMES = %w[README.md catalog.json navigation.json publication-manifest.json search-index.json].freeze
  RunResult = Struct.new(:output, :success, :exitstatus, keyword_init: true)

  def with_fixture
    Dir.mktmpdir("encyclopedia-security-") do |directory|
      root = Pathname(directory).join("repository")
      FileUtils.mkdir_p(root)
      FIXTURE_PATHS.each { |relative| FileUtils.cp_r(ROOT.join(relative), root.join(relative)) }
      yield root
    end
  end

  def run_command(root, *arguments)
    stdout, stderr, status = Open3.capture3(*arguments, chdir: root.to_s)
    RunResult.new(output: [stdout, stderr].join, success: status.success?, exitstatus: status.exitstatus)
  end

  def validator(root, *arguments)
    run_command(root, RbConfig.ruby, "scripts/validate-encyclopedia.rb", *arguments)
  end

  def builder(root, *arguments)
    run_command(root, RbConfig.ruby, "scripts/build-book.rb", *arguments)
  end

  def assert_failed(result, pattern)
    refute result.success, "expected command to fail, got:\n#{result.output}"
    assert_match pattern, result.output
  end

  def load_yaml(path)
    YAML.safe_load(File.read(path, encoding: "UTF-8"), aliases: false)
  end

  def write_yaml(path, value)
    File.binwrite(path, YAML.dump(value))
  end

  def write_file(root, relative, contents)
    path = root.join(relative)
    FileUtils.mkdir_p(path.dirname)
    File.binwrite(path, contents)
    relative
  end

  def generated_snapshot(root)
    GENERATED_NAMES.each_with_object({}) do |name, memo|
      memo[name] = Digest::SHA256.file(root.join("site/generated", name)).hexdigest
    end
  end

  def promote_first_chapter(root, &block)
    promote_chapter(root, index: 0, &block)
  end

  def promote_chapter(root, index:)
    catalog_path = root.join("curriculum/catalog.yml")
    catalog = load_yaml(catalog_path)
    catalog["status"] = "authoring"
    chapter = catalog.fetch("chapters").fetch(index)
    chapter["status"] = "verified"
    write_yaml(catalog_path, catalog)

    id = chapter.fetch("id")
    today = Date.today.iso8601
    example_directory = "examples/encyclopedia/#{id}"
    write_file(root, "#{example_directory}/example.txt", "public example\n")
    lab = write_file(root, "labs/encyclopedia/#{id}/lab.md", "# Reproducible lab\n")
    exercise = write_file(root, "exercises/encyclopedia/#{id}/exercise.md", "# Independent exercise\n")
    secret = "PRIVATE_SOLUTION_DO_NOT_PUBLISH_#{id}"
    solution = write_file(root, "solutions-private/encyclopedia/#{id}/solution.md", secret)

    evidence = {}
    %w[
      technical pedagogical code security accessibility version-sources
      publication-navigation links keyboard-semantics rendering
    ].each do |name|
      evidence[name] = write_file(
        root,
        "records/encyclopedia/evidence/#{id}/#{name}.txt",
        "#{name} review evidence for #{id}\n"
      )
    end

    gate = lambda do |name|
      {
        "status" => "passed",
        "evidence" => [evidence.fetch(name)],
        "checked_at" => today,
        "reviewer" => "reviewer-b"
      }
    end
    verification = {
      "technical" => gate.call("technical"),
      "pedagogical" => gate.call("pedagogical"),
      "code" => gate.call("code"),
      "security" => gate.call("security"),
      "accessibility" => gate.call("accessibility"),
      "version_sources" => gate.call("version-sources"),
      "publication_navigation" => gate.call("publication-navigation").merge(
        "coverage" => {
          "links" => { "status" => "passed", "evidence" => [evidence.fetch("links")] },
          "keyboard_semantics" => { "status" => "passed", "evidence" => [evidence.fetch("keyboard-semantics")] },
          "rendering" => { "status" => "passed", "evidence" => [evidence.fetch("rendering")] }
        }
      )
    }
    metadata = {
      "schema_version" => 1,
      "id" => id,
      "title" => chapter.fetch("title"),
      "volume" => chapter.fetch("volume"),
      "order" => chapter.fetch("order"),
      "level" => chapter.fetch("level"),
      "status" => "verified",
      "catalog" => "../../../curriculum/catalog.yml",
      "prerequisites" => chapter.fetch("prerequisites"),
      "outcomes" => chapter.fetch("outcomes"),
      "route_tags" => chapter.fetch("route_tags"),
      "stable_core" => chapter.fetch("stable_core"),
      "versioned_surface" => chapter.fetch("versioned_surface"),
      "verified_versions" => [],
      "source_refs" => [{
        "id" => "official-fixture",
        "title" => "Official fixture source",
        "url" => "https://example.invalid/official",
        "kind" => "official-doc",
        "checked_at" => today,
        "supports" => ["fixture claim"]
      }],
      "examples" => [example_directory],
      "labs" => [lab],
      "exercises" => [exercise],
      "solutions_private" => [solution],
      "author" => "author-a",
      "last_reviewed" => today,
      "verification" => verification
    }
    body = <<~MARKDOWN
      # #{chapter.fetch("title")}

      本章正文用于验证发布契约。它明确区分概念、适用边界、反例和可重复证据，并要求读者独立完成任务。这里的文字不是架构声明，也不是用构建成功代替技术正确性的自证。#{"可验证内容需要清晰来源、失败路径和复核记录。" * 5}

      ## 核心模型与边界

      读者先建立准确模型，再通过公开示例和实验观察输入、状态变化与输出。每个结论都说明适用条件；无法从当前证据推出的内容会明确标记，而不是凭空声称已经掌握。#{"这一段提供足够的教学正文和边界说明。" * 4}

      ## 实验、故障与复核

      实验保存命令、源码和结果，练习要求独立完成，解析位于私有目录。复核者检查技术、教学、代码、安全、无障碍、版本来源以及发布导航，实际渲染证据与链接和键盘语义检查分别保存。#{"修复后必须重跑原验证并保留证据。" * 4}
    MARKDOWN
    context = {
      chapter: chapter,
      metadata: metadata,
      body: body,
      chapter_path: chapter.fetch("path"),
      solution_path: solution,
      solution_secret: secret,
      evidence: evidence
    }
    yield context if block_given?
    save_chapter(root, context)
    context
  end

  def save_chapter(root, context)
    contents = "---\n#{YAML.dump(context.fetch(:metadata)).sub(/\A---\s*\n/, "")}---\n\n#{context.fetch(:body)}"
    File.binwrite(root.join(context.fetch(:chapter_path)), contents)
  end

  def test_baseline_build_is_deterministic_and_check_is_byte_exact
    with_fixture do |root|
      first = builder(root)
      assert first.success, first.output
      first_snapshot = generated_snapshot(root)

      second = builder(root)
      assert second.success, second.output
      assert_equal first_snapshot, generated_snapshot(root)

      check = builder(root, "--check")
      assert check.success, check.output
      assert_match(/BOOK BUILD CHECK OK/, check.output)
    end
  end

  def test_schema_definition_is_executable_and_fails_closed_on_unknown_type
    with_fixture do |root|
      path = root.join("schemas/chapter.schema.json")
      schema = JSON.parse(File.read(path, encoding: "UTF-8"))
      schema["type"] = "fictional-type"
      File.binwrite(path, JSON.pretty_generate(schema))

      assert_failed validator(root), /unsupported type "fictional-type"/
    end
  end

  def test_boolean_json_schemas_true_and_false_follow_draft_2020_12
    with_fixture do |root|
      path = root.join("schemas/chapter.schema.json")
      schema = JSON.parse(File.read(path, encoding: "UTF-8"))
      schema.fetch("properties")["title"] = true
      File.binwrite(path, JSON.pretty_generate(schema))

      result = validator(root)
      assert result.success, result.output
    end

    with_fixture do |root|
      path = root.join("schemas/chapter.schema.json")
      schema = JSON.parse(File.read(path, encoding: "UTF-8"))
      schema.fetch("properties")["title"] = false
      File.binwrite(path, JSON.pretty_generate(schema))

      assert_failed validator(root), /\/title: rejected by false schema/
    end
  end

  def test_json_schema_ref_siblings_are_evaluated
    with_fixture do |root|
      path = root.join("schemas/chapter.schema.json")
      schema = JSON.parse(File.read(path, encoding: "UTF-8"))
      schema.fetch("$defs")["chapter_title"] = { "type" => "string" }
      schema.fetch("properties")["title"] = {
        "$ref" => "#/$defs/chapter_title",
        "minLength" => 999
      }
      File.binwrite(path, JSON.pretty_generate(schema))

      assert_failed validator(root), /\/title: must contain at least 999 character/
    end
  end

  def test_json_schema_documents_reject_duplicate_object_members_at_any_level
    with_fixture do |root|
      path = root.join("schemas/version-registry.schema.json")
      contents = File.read(path, encoding: "UTF-8")
      duplicate = contents.sub(
        "\n  \"type\": \"object\",",
        "\n  \"type\": \"array\",\n  \"type\": \"object\","
      )
      refute_equal contents, duplicate
      File.binwrite(path, duplicate)

      assert_failed validator(root), /duplicate JSON object member "type"/
    end
  end

  def test_registry_additional_properties_rule_is_actually_executed
    with_fixture do |root|
      path = root.join("versions/registry.yml")
      registry = load_yaml(path)
      registry["self_asserted_verified"] = true
      write_yaml(path, registry)

      assert_failed validator(root), /additional property self_asserted_verified is not allowed/
    end
  end

  def test_site_config_schema_is_executed
    with_fixture do |root|
      path = root.join("site/config.yml")
      config = load_yaml(path)
      config.delete("title")
      write_yaml(path, config)

      assert_failed validator(root), /site\/config\.yml: \$: missing required property title/
    end
  end

  def test_future_registry_dates_are_rejected
    with_fixture do |root|
      path = root.join("versions/registry.yml")
      registry = load_yaml(path)
      registry["verified_at"] = "2999-12-31"
      registry.fetch("entries").first["verified_at"] = "2999-12-31"
      write_yaml(path, registry)

      result = validator(root)
      assert_failed result, /verified_at cannot be in the future/
      assert_match(/entry #1 verified_at cannot be in the future/, result.output)
    end
  end

  def test_registry_catalog_and_site_editions_must_match
    with_fixture do |root|
      path = root.join("versions/registry.yml")
      registry = load_yaml(path)
      registry["edition"] = "different-edition"
      write_yaml(path, registry)

      assert_failed validator(root), /edition mismatch across registry\/catalog\/site/
    end
  end

  def test_registry_source_urls_require_https_host_and_allow_precise_fragments
    with_fixture do |root|
      path = root.join("versions/registry.yml")
      registry = load_yaml(path)
      registry.fetch("entries").first["source_url"] = "https://"
      write_yaml(path, registry)

      assert_failed validator(root), /entry #1 source_url must be an absolute HTTPS URI with a non-empty host/
    end

    with_fixture do |root|
      path = root.join("versions/registry.yml")
      registry = load_yaml(path)
      registry.fetch("entries").first["source_url"] = "https://example.invalid/docs#precise-section"
      write_yaml(path, registry)

      result = validator(root)
      assert result.success, result.output
    end
  end

  def test_build_invokes_the_strict_curriculum_validator
    with_fixture do |root|
      path = root.join("curriculum/catalog.yml")
      catalog = load_yaml(path)
      catalog.fetch("chapters").first["prerequisites"] = ["v99.c99.does-not-exist"]
      write_yaml(path, catalog)

      assert_failed builder(root), /strict curriculum validation failed.*unknown prerequisites/m
    end
  end

  def test_validator_directly_invokes_the_strict_curriculum_validator
    with_fixture do |root|
      path = root.join("curriculum/catalog.yml")
      catalog = load_yaml(path)
      catalog.fetch("chapters").first["prerequisites"] = ["v99.c99.does-not-exist"]
      write_yaml(path, catalog)

      assert_failed validator(root), /strict curriculum validation failed.*unknown prerequisites/m
    end
  end

  def test_duplicate_yaml_keys_are_rejected_in_auxiliary_documents_and_front_matter
    with_fixture do |root|
      route = root.join("curriculum/routes/zero-base.yml")
      contents = File.read(route, encoding: "UTF-8")
      contents.sub!("route_id: zero-base\n", "route_id: zero-base\nroute_id: duplicate\n")
      File.binwrite(route, contents)

      assert_failed validator(root), /duplicate mapping key "route_id"/
    end

    with_fixture do |root|
      catalog = load_yaml(root.join("curriculum/catalog.yml"))
      chapter = root.join(catalog.fetch("chapters").first.fetch("path"))
      contents = File.read(chapter, encoding: "UTF-8")
      contents.sub!("status: planned\n", "status: planned\nstatus: planned\n")
      File.binwrite(chapter, contents)

      assert_failed validator(root), /duplicate mapping key "status"/
    end
  end

  def test_chapter_symlink_is_rejected_even_when_target_stays_inside_repository
    with_fixture do |root|
      catalog = load_yaml(root.join("curriculum/catalog.yml"))
      path = root.join(catalog.fetch("chapters").first.fetch("path"))
      real = Pathname("#{path}.real")
      FileUtils.mv(path, real)
      File.symlink(real.basename.to_s, path)

      assert_failed validator(root), /canonical input .*learning-evidence\.md: symbolic link component is forbidden/
    end
  end

  def test_direct_validator_rejects_schema_registry_and_catalog_symlinks
    %w[
      schemas/site-config.schema.json
      versions/registry.yml
      curriculum/catalog.yml
    ].each do |relative|
      with_fixture do |root|
        path = root.join(relative)
        real = Pathname("#{path}.real#{path.extname}")
        FileUtils.mv(path, real)
        File.symlink(real.basename.to_s, path)

        result = validator(root)
        assert_failed result, /canonical input #{Regexp.escape(relative)}: symbolic link component is forbidden/
        refute_match(/ENCYCLOPEDIA VALID/, result.output)
      end
    end
  end

  def test_output_directory_symlink_is_rejected_without_writing_outside
    with_fixture do |root|
      output = root.join("site/generated")
      outside = root.parent.join("outside-output")
      FileUtils.rm_rf(output)
      FileUtils.mkdir_p(outside)
      File.symlink(outside, output)

      result = builder(root)
      assert_failed result, /site output: symbolic link component is forbidden|site output: symbolic links are forbidden/
      assert_empty Dir.children(outside)
    end
  end

  def test_verified_placeholder_cannot_fake_artifacts_gates_or_independent_review
    with_fixture do |root|
      context = promote_first_chapter(root) do |fixture|
        id = fixture.fetch(:chapter).fetch("id")
        metadata = fixture.fetch(:metadata)
        metadata["examples"] = ["examples/encyclopedia/v99.c99.other/missing"]
        metadata["labs"] = ["labs/encyclopedia/#{id}/missing.md"]
        metadata["exercises"] = ["exercises/encyclopedia/#{id}/missing.md"]
        metadata["solutions_private"] = ["/tmp/private-solution.md"]
        metadata.fetch("verification").each_value do |gate|
          gate["status"] = "not-applicable"
          gate["reviewer"] = metadata.fetch("author")
          gate["applicability_reason"] = "self asserted without independent evidence"
        end
        metadata.fetch("verification").fetch("publication_navigation").fetch("coverage").fetch("rendering")["status"] = "pending"
        fixture[:body] = "# Placeholder\n\n> 架构占位：没有正文。\n"
      end

      result = validator(root)
      assert_failed result, /examples #1: path is outside its allowed chapter artifact directory/
      assert_match(/artifact does not exist/, result.output)
      assert_match(/solutions_private #1: absolute paths are forbidden/, result.output)
      assert_match(/reviewer must be independent from author/, result.output)
      assert_match(/requires technical gate to pass/, result.output)
      assert_match(/publication_navigation requires rendering coverage to pass/, result.output)
      assert_match(/verified chapter must not contain placeholder marker/, result.output)
      assert_equal "verified", context.fetch(:metadata).fetch("status")
    end
  end

  def test_empty_artifact_directory_cannot_satisfy_review_contract
    with_fixture do |root|
      promote_first_chapter(root) do |fixture|
        id = fixture.fetch(:chapter).fetch("id")
        empty = "labs/encyclopedia/#{id}/empty"
        FileUtils.mkdir_p(root.join(empty))
        write_file(root, "#{empty}/.hidden-proof.txt", "hidden content")
        write_file(root, "#{empty}/visible-but-blank.txt", " \n\t　")
        fixture.fetch(:metadata)["labs"] = [empty]
      end

      assert_failed validator(root), /artifact directory must contain a non-hidden, non-whitespace regular file/
    end
  end

  def test_artifact_and_evidence_files_must_contain_non_whitespace_content
    with_fixture do |root|
      context = promote_first_chapter(root)
      lab = context.fetch(:metadata).fetch("labs").first
      File.binwrite(root.join(lab), " \n\t　")
      technical_evidence = context.fetch(:evidence).fetch("technical")
      File.binwrite(root.join(technical_evidence), " \n\t　")

      result = validator(root)
      assert_failed result, /labs #1: artifact file must contain non-whitespace content/
      assert_match(/verification technical evidence #1: file must contain non-whitespace content/, result.output)
    end
  end

  def test_author_and_reviewer_identity_use_trim_nfkc_and_casefold
    with_fixture do |root|
      promote_first_chapter(root) do |fixture|
        metadata = fixture.fetch(:metadata)
        metadata["author"] = "Ａlice"
        metadata.fetch("verification").fetch("technical")["reviewer"] = " alice "
        metadata.fetch("verification").fetch("pedagogical")["reviewer"] = "　a　"
      end

      result = validator(root)
      assert_failed result, /verification technical reviewer must be independent from author/
      assert_match(/verification pedagogical reviewer must contain at least two non-whitespace characters/, result.output)
    end

    with_fixture do |root|
      promote_first_chapter(root) { |fixture| fixture.fetch(:metadata)["author"] = "　 \t" }

      assert_failed validator(root), /author must contain at least two non-whitespace characters/
    end
  end

  def test_evidence_symlink_is_rejected
    with_fixture do |root|
      context = promote_first_chapter(root)
      path = root.join(context.fetch(:evidence).fetch("technical"))
      FileUtils.rm_f(path)
      File.symlink("pedagogical.txt", path)

      assert_failed validator(root), /verification technical evidence #1: symbolic link component is forbidden/
    end
  end

  def test_gate_and_version_evidence_must_exist_in_evidence_root
    with_fixture do |root|
      context = promote_first_chapter(root)
      catalog_path = root.join("curriculum/catalog.yml")
      catalog = load_yaml(catalog_path)
      catalog.fetch("chapters").first["versioned_surface"] = ["browser"]
      write_yaml(catalog_path, catalog)

      metadata = context.fetch(:metadata)
      metadata["versioned_surface"] = ["browser"]
      metadata["verified_versions"] = [{
        "id" => "browser",
        "constraint" => "current stable",
        "verified_at" => Date.today.iso8601,
        "evidence" => "records/encyclopedia/evidence/#{context.fetch(:chapter).fetch("id")}/missing-version.txt"
      }]
      metadata.fetch("verification").fetch("technical")["evidence"] = ["site/index.html"]
      save_chapter(root, context)

      result = validator(root)
      assert_failed result, /verified_versions #1 evidence: file does not exist/
      assert_match(/verification technical evidence #1: path is outside its allowed directory/, result.output)
      assert_match(/does not match required pattern/, result.output)
    end
  end

  def test_verified_version_constraint_must_match_the_registry_contract
    with_fixture do |root|
      context = promote_first_chapter(root)
      catalog_path = root.join("curriculum/catalog.yml")
      catalog = load_yaml(catalog_path)
      catalog.fetch("chapters").first["versioned_surface"] = ["browser"]
      write_yaml(catalog_path, catalog)

      metadata = context.fetch(:metadata)
      metadata["versioned_surface"] = ["browser"]
      metadata["verified_versions"] = [{
        "id" => "browser",
        "constraint" => "whatever-latest",
        "verified_at" => Date.today.iso8601,
        "evidence" => context.fetch(:evidence).fetch("version-sources")
      }]
      save_chapter(root, context)

      assert_failed validator(root), /verified_versions #1 constraint must exactly match registry constraint/
    end
  end

  def test_future_chapter_review_dates_are_rejected
    with_fixture do |root|
      promote_first_chapter(root) do |fixture|
        fixture.fetch(:metadata)["last_reviewed"] = "2999-12-31"
        fixture.fetch(:metadata).fetch("verification").fetch("technical")["checked_at"] = "2999-12-31"
        fixture.fetch(:metadata).fetch("source_refs").first["checked_at"] = "2999-12-31"
      end

      result = validator(root)
      assert_failed result, /last_reviewed cannot be in the future/
      assert_match(/verification technical checked_at cannot be in the future/, result.output)
      assert_match(/source_refs #1 checked_at cannot be in the future/, result.output)
    end
  end

  def test_valid_seven_gate_verified_chapter_passes_encyclopedia_contract
    with_fixture do |root|
      promote_first_chapter(root)

      result = validator(root)
      assert result.success, result.output
      assert_match(/status_verified=1/, result.output)
      refute_match(/content_truth=verified/, result.output)
    end
  end

  def test_verified_hard_prerequisite_transitive_closure_must_be_verified
    with_fixture do |root|
      context = promote_chapter(root, index: 8)

      result = validator(root)
      assert_failed result, /#{Regexp.escape(context.fetch(:chapter).fetch("id"))} verified hard-prerequisite closure contains non-verified chapters/
      assert_match(/v00\.c03\.files-paths-encoding\(planned\)/, result.output)
    end
  end

  def test_review_and_verified_bodies_reject_placeholders_and_empty_prose
    with_fixture do |root|
      context = promote_first_chapter(root)
      catalog_path = root.join("curriculum/catalog.yml")
      catalog = load_yaml(catalog_path)
      catalog.fetch("chapters").first["status"] = "review"
      write_yaml(catalog_path, catalog)
      context.fetch(:metadata)["status"] = "review"
      context[:body] = "# Review\n\n> 架构占位\n"
      save_chapter(root, context)

      assert_failed validator(root), /review chapter must not contain placeholder marker/
    end

    with_fixture do |root|
      context = promote_first_chapter(root)
      catalog_path = root.join("curriculum/catalog.yml")
      catalog = load_yaml(catalog_path)
      catalog.fetch("chapters").first["status"] = "review"
      write_yaml(catalog_path, catalog)
      context.fetch(:metadata)["status"] = "review"
      context[:body] = ""
      save_chapter(root, context)

      assert_failed validator(root), /review chapter body must contain non-whitespace prose/
    end

    with_fixture do |root|
      context = promote_first_chapter(root)
      context[:body] = ""
      save_chapter(root, context)

      assert_failed validator(root), /verified chapter body must contain non-whitespace prose/
    end
  end

  def test_review_body_with_only_title_and_todo_is_too_small_and_unstructured
    with_fixture do |root|
      context = promote_first_chapter(root)
      catalog_path = root.join("curriculum/catalog.yml")
      catalog = load_yaml(catalog_path)
      catalog.fetch("chapters").first["status"] = "review"
      write_yaml(catalog_path, catalog)
      context.fetch(:metadata)["status"] = "review"
      context[:body] = "# Review draft\n\nTODO\n"
      save_chapter(root, context)

      result = validator(root)
      assert_failed result, /review chapter needs at least two level-2 sections/
      assert_match(/review chapter prose is too small for review/, result.output)
      assert_match(/standalone TODO\/TBD placeholder lines/, result.output)
      refute_match(/trailing whitespace|missing final newline/, result.output)
    end
  end

  def test_source_refs_require_unique_ids_and_a_real_https_host
    with_fixture do |root|
      promote_first_chapter(root) do |fixture|
        sources = fixture.fetch(:metadata).fetch("source_refs")
        duplicate = sources.first.dup
        duplicate["supports"] = sources.first.fetch("supports").dup
        duplicate["url"] = "https://"
        sources << duplicate
      end

      result = validator(root)
      assert_failed result, /duplicate source_refs id official-fixture/
      assert_match(/source_refs #2 url must be an absolute HTTPS URI with a non-empty host/, result.output)
    end
  end

  def test_private_solutions_never_enter_manifest_or_public_output
    with_fixture do |root|
      context = promote_first_chapter(root)

      result = builder(root)
      assert result.success, result.output
      manifest = JSON.parse(File.read(root.join("site/generated/publication-manifest.json"), encoding: "UTF-8"))
      input_names = manifest.fetch("inputs").keys
      refute input_names.any? { |name| name.start_with?("solutions-private/") }
      assert input_names.any? { |name| name.start_with?("examples/encyclopedia/") }
      assert input_names.any? { |name| name.start_with?("labs/encyclopedia/") }
      assert input_names.any? { |name| name.start_with?("exercises/encyclopedia/") }
      assert input_names.any? { |name| name.start_with?("records/encyclopedia/evidence/") }

      public_bytes = GENERATED_NAMES.map { |name| File.binread(root.join("site/generated", name)) }.join("\n")
      refute_includes public_bytes, context.fetch(:solution_path)
      refute_includes public_bytes, context.fetch(:solution_secret)
      search = JSON.parse(File.read(root.join("site/generated/search-index.json"), encoding: "UTF-8"))
      assert_equal [context.fetch(:chapter).fetch("id")], search.map { |entry| entry.fetch("id") }
    end
  end

  def test_tampered_generated_bytes_are_rejected
    with_fixture do |root|
      result = builder(root)
      assert result.success, result.output
      File.open(root.join("site/generated/navigation.json"), "ab") { |file| file.write("tampered") }

      assert_failed builder(root, "--check"), /stale site\/generated\/navigation\.json/
    end
  end

  def test_unexpected_generated_file_is_rejected
    with_fixture do |root|
      result = builder(root)
      assert result.success, result.output
      File.binwrite(root.join("site/generated/answers-private.json"), "secret")

      assert_failed builder(root, "--check"), /unexpected site\/generated\/answers-private\.json/
    end
  end

  def test_volume_readme_is_covered_by_manifest_input_digest
    with_fixture do |root|
      first = builder(root)
      assert first.success, first.output
      manifest_path = root.join("site/generated/publication-manifest.json")
      before = JSON.parse(File.read(manifest_path, encoding: "UTF-8")).fetch("input_digest")
      readme = Dir.glob(root.join("book/volume-00-*/README.md").to_s).first
      File.open(readme, "ab") { |file| file.write("\n<!-- manifest digest mutation -->\n") }

      second = builder(root)
      assert second.success, second.output
      after = JSON.parse(File.read(manifest_path, encoding: "UTF-8")).fetch("input_digest")
      refute_equal before, after
    end
  end

  def test_progress_and_assessments_are_manifest_inputs_and_progress_drift_fails_check
    with_fixture do |root|
      result = builder(root)
      assert result.success, result.output
      manifest = JSON.parse(File.read(root.join("site/generated/publication-manifest.json"), encoding: "UTF-8"))
      assert_includes manifest.fetch("inputs").keys, "ASSESSMENTS.md"
      assert_includes manifest.fetch("inputs").keys, "PROGRESS.md"

      File.open(root.join("PROGRESS.md"), "ab") { |file| file.write("\n<!-- fixture-only digest change -->\n") }
      assert_failed builder(root, "--check"), /stale site\/generated\/(?:README|catalog|navigation|publication-manifest)/
    end
  end
end
