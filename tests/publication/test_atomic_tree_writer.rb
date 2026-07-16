# frozen_string_literal: true

require_relative "test_helper"

class AtomicTreeWriterTest < Minitest::Test
  include PublicationFixture

  PROFILE_ID = "p3-gold"

  def with_writer_root
    Dir.mktmpdir("publication-atomic-") do |directory|
      root = Pathname(directory).join("repository")
      FileUtils.mkdir_p(root)
      yield root
    end
  end

  def test_write_and_check_compare_non_ascii_bytes_and_reject_extras
    with_writer_root do |root|
      writer = Publication::AtomicTreeWriter.new(root.to_s)
      content = "{\"notice\":\"内部预览\"}\n"
      writer.write(PROFILE_ID, content)
      assert writer.check(PROFILE_ID, content)

      output = root.join("build/publication", PROFILE_ID)
      File.binwrite(output.join("stale.txt"), "stale\n")
      assert_contract_code("E_OUTPUT_EXTRA") { writer.check(PROFILE_ID, content) }

      writer.write(PROFILE_ID, content)
      assert_equal ["publication-plan.json"], Dir.children(output)
    end
  end

  def test_failed_replacement_restores_the_previous_complete_tree
    with_writer_root do |root|
      old_content = "{\"version\":1}\n"
      new_content = "{\"version\":2}\n"
      Publication::AtomicTreeWriter.new(root.to_s).write(PROFILE_ID, old_content)
      rename_count = 0
      renamer = lambda do |source, destination|
        rename_count += 1
        raise IOError, "injected promotion failure" if rename_count == 2

        File.rename(source, destination)
      end
      writer = Publication::AtomicTreeWriter.new(root.to_s, renamer: renamer)

      assert_contract_code("E_ATOMIC_PROMOTION") { writer.write(PROFILE_ID, new_content) }
      output = root.join("build/publication", PROFILE_ID, "publication-plan.json")
      assert_equal old_content.b, File.binread(output)
      assert_empty Dir.glob(root.join("build/publication/.p3-gold.backup-*").to_s)
      assert_empty Dir.glob(root.join("build/publication/.p3-gold.stage-*").to_s)
    end
  end

  def test_failed_rollback_preserves_the_backup_for_manual_recovery
    with_writer_root do |root|
      old_content = "{\"version\":1}\n"
      Publication::AtomicTreeWriter.new(root.to_s).write(PROFILE_ID, old_content)
      rename_count = 0
      renamer = lambda do |source, destination|
        rename_count += 1
        raise IOError, "injected rename failure" if rename_count >= 2

        File.rename(source, destination)
      end
      writer = Publication::AtomicTreeWriter.new(root.to_s, renamer: renamer)

      assert_contract_code("E_ROLLBACK_FAILED") { writer.write(PROFILE_ID, "{\"version\":2}\n") }
      refute root.join("build/publication", PROFILE_ID).exist?
      backups = Dir.glob(root.join("build/publication/.p3-gold.backup-*").to_s)
      stages = Dir.glob(root.join("build/publication/.p3-gold.stage-*").to_s)
      assert_equal 1, backups.length
      assert_equal 1, stages.length
      assert_equal old_content.b, File.binread(File.join(backups.first, "publication-plan.json"))
      assert_equal "{\"version\":2}\n".b, File.binread(File.join(stages.first, "publication-plan.json"))
    end
  end

  def test_first_promotion_failure_leaves_no_partial_output
    with_writer_root do |root|
      renamer = ->(_source, _destination) { raise IOError, "injected first promotion failure" }
      writer = Publication::AtomicTreeWriter.new(root.to_s, renamer: renamer)

      assert_contract_code("E_ATOMIC_PROMOTION") { writer.write(PROFILE_ID, "{}\n") }
      refute root.join("build/publication", PROFILE_ID).exist?
      assert_empty Dir.glob(root.join("build/publication/.p3-gold.*-*").to_s)
    end
  end

  def test_write_and_check_reject_symbolic_link_output_parents
    with_writer_root do |root|
      external = root.parent.join("external-build")
      FileUtils.mkdir_p(external)
      File.symlink(external, root.join("build"))
      writer = Publication::AtomicTreeWriter.new(root.to_s)

      assert_contract_code("E_OUTPUT_SYMLINK") { writer.write(PROFILE_ID, "{}\n") }
      assert_contract_code("E_OUTPUT_SYMLINK") { writer.check(PROFILE_ID, "{}\n") }
    end
  end

  def test_parent_sync_failure_restores_previous_tree_before_reporting_failure
    writer_class = Class.new(Publication::AtomicTreeWriter) do
      def initialize(*arguments, fail_sync_on:, **options)
        @sync_count = 0
        @fail_sync_on = fail_sync_on
        super(*arguments, **options)
      end

      private

      def fsync_directory(directory)
        @sync_count += 1
        raise IOError, "injected directory sync failure" if @sync_count == @fail_sync_on

        super
      end
    end

    with_writer_root do |root|
      old_content = "{\"version\":1}\n"
      Publication::AtomicTreeWriter.new(root.to_s).write(PROFILE_ID, old_content)
      writer = writer_class.new(root.to_s, fail_sync_on: 2)

      assert_contract_code("E_ATOMIC_DURABILITY") { writer.write(PROFILE_ID, "{\"version\":2}\n") }
      output = root.join("build/publication", PROFILE_ID, "publication-plan.json")
      assert_equal old_content.b, File.binread(output)
      assert_empty Dir.glob(root.join("build/publication/.p3-gold.backup-*").to_s)
      assert_empty Dir.glob(root.join("build/publication/.p3-gold.stage-*").to_s)
    end
  end
end
