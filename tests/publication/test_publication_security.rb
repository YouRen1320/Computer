# frozen_string_literal: true

require "open3"
require "rbconfig"

require_relative "test_helper"

class PublicationSecurityTest < Minitest::Test
  include PublicationFixture

  PLATFORM_MANIFEST = "publication/manifests/public-artifacts/ch.java.platform-toolchain.yml"
  PLATFORM_README = "examples/encyclopedia/ch.java.platform-toolchain/README.md"

  def test_rejects_undeclared_file_and_private_canaries
    with_publication_fixture do |root|
      File.binwrite(root.join("examples/encyclopedia/ch.java.platform-toolchain/undeclared.txt"), "not declared\n")
      assert_contract_code("E_ARTIFACT_EXTRA") { fixture_builder(root).build }
    end

    with_publication_fixture do |root|
      File.open(root.join(PLATFORM_README), "ab") do |file|
        file.write("\nPRIVATE_SOLUTION_DO_NOT_PUBLISH_FIXTURE\n")
      end
      assert_contract_code("E_PRIVATE_CANARY") { fixture_builder(root).build }
    end

    with_publication_fixture do |root|
      chapter = root.join("book/volume-01-java-language/chapters/ch.java.platform-toolchain.md")
      File.open(chapter, "ab") { |file| file.write("\nPRIVATE_SOLUTION_DO_NOT_PUBLISH_CHAPTER\n") }
      assert_contract_code("E_PRIVATE_CANARY") { fixture_builder(root).build }
    end
  end

  def test_rejects_symbolic_link_inputs
    with_publication_fixture do |root|
      path = root.join(PLATFORM_README)
      FileUtils.rm_f(path)
      File.symlink(root.join("curriculum/catalog.yml"), path)
      assert_contract_code("E_PATH_SYMLINK") { fixture_builder(root).build }
    end

    with_publication_fixture do |root|
      owned_root = root.join("examples/encyclopedia/ch.java.platform-toolchain")
      external_root = root.join("fixture-external-platform-root")
      FileUtils.mv(owned_root, external_root)
      File.symlink(external_root, owned_root)
      assert_contract_code("E_PATH_SYMLINK") { fixture_builder(root).build }
    end
  end

  def test_rejects_private_canary_in_repository_metadata
    with_publication_fixture do |root|
      metadata = root.join("labs/encyclopedia/ch.java.platform-toolchain/.gitignore")
      File.open(metadata, "ab") { |file| file.write("\nPRIVATE_SOLUTION_DO_NOT_PUBLISH_METADATA\n") }
      assert_contract_code("E_PRIVATE_CANARY") { fixture_builder(root).build }
    end
  end

  def test_rejects_cross_chapter_ownership_and_traversal
    with_publication_fixture do |root|
      manifest = read_yaml(root, PLATFORM_MANIFEST)
      manifest.fetch("artifacts").first["source_path"] =
        "examples/encyclopedia/ch.java.program-structure/README.md"
      write_yaml(root, PLATFORM_MANIFEST, manifest)
      assert_contract_code("E_PATH_OWNERSHIP") { fixture_builder(root).build }
    end

    with_publication_fixture do |root|
      manifest = read_yaml(root, PLATFORM_MANIFEST)
      manifest.fetch("artifacts").first["source_path"] = "../../solutions-private/answer.md"
      write_yaml(root, PLATFORM_MANIFEST, manifest)
      assert_contract_code("E_SCHEMA_INSTANCE") { fixture_builder(root).build }
    end
  end

  def test_rejects_hidden_and_generated_public_artifacts
    with_publication_fixture do |root|
      add_artifact(
        root,
        source_path: "examples/encyclopedia/ch.java.platform-toolchain/.secret.txt",
        artifact_id: "hidden-secret"
      )
      assert_contract_code("E_SCHEMA_INSTANCE") { fixture_builder(root).build }
    end

    with_publication_fixture do |root|
      add_artifact(
        root,
        source_path: "examples/encyclopedia/ch.java.platform-toolchain/target/generated.txt",
        artifact_id: "generated-output"
      )
      assert_contract_code("E_ARTIFACT_GENERATED") { fixture_builder(root).build }
    end
  end

  def test_rejects_absolute_profile_path_before_reading_it
    with_publication_fixture do |root|
      builder = Publication::PlanBuilder.new(
        root.to_s,
        profile_path: root.join(PROFILE_PATH).to_s,
        p2_checker: -> { true },
        tool_observer: ->(_command) { ["ruby 2.6.10p210", true] }
      )
      error = assert_contract_code("E_PATH_ABSOLUTE") { builder.build }
      refute_includes error.diagnostic, root.to_s
      assert_includes error.diagnostic, "<redacted-path>"
    end
  end

  def test_cli_does_not_echo_unexpected_positional_argument_values
    payload = "FAKE_PRIVATE_PAYLOAD"
    _stdout, stderr, status = Open3.capture3(
      RbConfig.ruby,
      PublicationFixture::ROOT.join("scripts/build-publication-plan.rb").to_s,
      payload,
      chdir: PublicationFixture::ROOT.to_s
    )

    refute status.success?
    assert_equal 2, status.exitstatus
    refute_includes stderr, payload
    assert_includes stderr, "invalid command-line arguments"
  end

  private

  def add_artifact(root, source_path:, artifact_id:)
    path = root.join(source_path)
    FileUtils.mkdir_p(path.dirname)
    File.binwrite(path, "fixture\n")
    manifest = read_yaml(root, PLATFORM_MANIFEST)
    manifest.fetch("artifacts") << {
      "artifact_id" => artifact_id,
      "role" => "example-source",
      "source_path" => source_path,
      "media_type" => "text/plain",
      "presentation" => "listing",
      "target_formats" => %w[html epub pdf]
    }
    write_yaml(root, PLATFORM_MANIFEST, manifest)
  end
end
