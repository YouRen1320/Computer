# frozen_string_literal: true

require "fileutils"
require "minitest/autorun"
require "pathname"
require "tmpdir"
require "yaml"

require_relative "../../publication/lib/atomic_tree_writer"
require_relative "../../publication/lib/plan_builder"

module PublicationFixture
  ROOT = Pathname(__dir__).join("../..").expand_path.freeze
  PROFILE_PATH = "publication/profiles/p3-gold.yml"
  GOLD_IDS = Publication::P3_GOLD_IDS.freeze
  CONTRACT_PATHS = [
    "curriculum/catalog.yml",
    "publication/lib",
    "publication/manifests/public-artifacts",
    "publication/profiles/p3-gold.yml",
    "publication/toolchain.yml",
    "schemas/public-artifact-manifest.schema.json",
    "schemas/publication-output-manifest.schema.json",
    "schemas/publication-plan.schema.json",
    "schemas/publication-profile.schema.json",
    "schemas/publication-toolchain.schema.json",
    "scripts/build-publication-plan.rb",
    "site/generated"
  ].freeze

  def with_publication_fixture
    Dir.mktmpdir("publication-r1a-") do |directory|
      root = Pathname(directory).join("repository")
      FileUtils.mkdir_p(root)
      fixture_paths.each { |relative| copy_path(root, relative) }
      yield root
    end
  end

  def fixture_builder(root, tool_observer: nil)
    observer = tool_observer || lambda { |_command| ["ruby 2.6.10p210 (fixture)", true] }
    Publication::PlanBuilder.new(
      root.to_s,
      profile_path: PROFILE_PATH,
      p2_checker: -> { true },
      tool_observer: observer
    )
  end

  def read_yaml(root, relative)
    StrictYaml.safe_load(
      File.read(root.join(relative), encoding: "UTF-8"),
      label: relative
    )
  end

  def write_yaml(root, relative, value)
    File.binwrite(root.join(relative), YAML.dump(value))
  end

  def assert_contract_code(code)
    error = assert_raises(Publication::ContractError) { yield }
    assert_equal code, error.code, error.diagnostic
    error
  end

  private

  def fixture_paths
    artifact_paths = GOLD_IDS.flat_map do |id|
      [
        "book/volume-01-java-language/chapters/#{id}.md",
        "examples/encyclopedia/#{id}",
        "labs/encyclopedia/#{id}",
        "exercises/encyclopedia/#{id}"
      ]
    end
    (CONTRACT_PATHS + artifact_paths).uniq
  end

  def copy_path(root, relative)
    source = ROOT.join(relative)
    destination = root.join(relative)
    FileUtils.mkdir_p(destination.dirname)
    FileUtils.cp_r(source, destination, preserve: true)
  end
end
