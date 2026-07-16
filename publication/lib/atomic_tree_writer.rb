# frozen_string_literal: true

require "digest"
require "fileutils"

require_relative "contract"

module Publication
  # Build the complete R1-A sidecar tree in a sibling staging directory, then
  # promote it with rename. A failed promotion restores the previous tree. If
  # restoration itself fails, the backup is deliberately preserved for manual
  # recovery instead of being deleted by an ensure block.
  class AtomicTreeWriter
    attr_reader :root, :renamer

    def initialize(root, renamer: nil)
      @root = File.realpath(root)
      @renamer = renamer || lambda { |source, destination| File.rename(source, destination) }
    end

    def write(profile_id, content)
      parent = prepare_parent
      output = output_directory_for(profile_id)
      staging = File.join(parent, ".#{profile_id}.stage-#{$$}-#{rand(1_000_000)}")
      backup = File.join(parent, ".#{profile_id}.backup-#{$$}-#{rand(1_000_000)}")
      [staging, backup].each do |path|
        if File.exist?(path) || File.symlink?(path)
          raise ContractError.new("commit", "E_TEMP_EXISTS", "temporary publication path already exists")
        end
      end

      backup_created = false
      staging_created = false
      preserve_recovery = false
      committed = false
      begin
        Dir.mkdir(staging, 0o755)
        staging_created = true
        plan_path = File.join(staging, "publication-plan.json")
        File.open(plan_path, File::WRONLY | File::CREAT | File::EXCL, 0o644) do |file|
          file.binmode
          file.write(content)
          file.flush
          file.fsync
        end
        validate_staged_tree!(staging, content)
        fsync_directory(staging)

        if File.exist?(output) || File.symlink?(output)
          validate_existing_output!(output)
          renamer.call(output, backup)
          backup_created = true
        end
        begin
          renamer.call(staging, output)
          staging_created = false
          begin
            fsync_directory(parent)
          rescue StandardError => durability_error
            begin
              renamer.call(output, staging)
              staging_created = true
              if backup_created
                renamer.call(backup, output)
                backup_created = false
              end
              fsync_directory(parent)
            rescue StandardError
              preserve_recovery = true
              raise ContractError.new(
                "rollback",
                "E_ROLLBACK_FAILED",
                "publication durability sync failed and recovery trees were preserved"
              )
            end
            raise ContractError.new(
              "commit",
              "E_ATOMIC_DURABILITY",
              "publication durability sync failed; the previous tree was restored (#{durability_error.class})"
            )
          end
        rescue StandardError => promotion_error
          raise if promotion_error.is_a?(ContractError)

          if backup_created
            begin
              renamer.call(backup, output)
              backup_created = false
              fsync_directory(parent)
            rescue StandardError
              preserve_recovery = true
              raise ContractError.new(
                "rollback",
                "E_ROLLBACK_FAILED",
                "publication promotion failed and recovery trees were preserved"
              )
            end
          end
          raise ContractError.new("commit", "E_ATOMIC_PROMOTION", "atomic tree promotion failed (#{promotion_error.class})")
        end

        committed = true
        if backup_created && File.directory?(backup) && !File.symlink?(backup)
          FileUtils.rm_rf(backup)
          backup_created = false unless File.exist?(backup) || File.symlink?(backup)
        end
      rescue ContractError
        raise
      rescue StandardError => e
        raise ContractError.new("commit", "E_ATOMIC_COMMIT", "atomic publication commit failed (#{e.class})")
      ensure
        unless preserve_recovery
          FileUtils.rm_rf(staging) if staging_created && File.directory?(staging) && !File.symlink?(staging)
          # Once the parent-directory sync succeeds, the new output is the
          # commit point. A leftover backup is cleanup-only and can be removed.
          if committed && File.directory?(backup) && !File.symlink?(backup)
            FileUtils.rm_rf(backup)
          end
        end
      end
      File.join(output, "publication-plan.json")
    end

    def check(profile_id, expected_content)
      validate_parent
      output = output_directory_for(profile_id)
      validate_existing_output!(output)
      entries = Dir.children(output).sort
      expected = ["publication-plan.json"]
      extra = entries - expected
      missing = expected - entries
      raise ContractError.new("check", "E_OUTPUT_EXTRA", "unexpected sidecar output #{extra.first}") unless extra.empty?
      raise ContractError.new("check", "E_OUTPUT_MISSING", "missing sidecar output #{missing.first}") unless missing.empty?

      path = File.join(output, "publication-plan.json")
      stat = File.lstat(path)
      unless stat.file? && !stat.symlink?
        raise ContractError.new("check", "E_OUTPUT_UNSAFE", "publication plan must be a regular file")
      end
      actual = File.binread(path)
      unless actual == expected_content.b
        raise ContractError.new("check", "E_OUTPUT_STALE", "publication plan differs from canonical inputs")
      end
      true
    rescue Errno::ENOENT
      raise ContractError.new("check", "E_OUTPUT_MISSING", "publication output is missing")
    end

    def output_directory_for(profile_id)
      validate_profile_id!(profile_id)
      File.join(root, "build", "publication", profile_id)
    end

    private

    def prepare_parent
      publication_parent(create_missing: true)
    end

    def validate_parent
      publication_parent(create_missing: false)
    end

    def publication_parent(create_missing:)
      cursor = root
      %w[build publication].each do |component|
        cursor = File.join(cursor, component)
        if File.exist?(cursor) || File.symlink?(cursor)
          stat = File.lstat(cursor)
          raise ContractError.new("inventory", "E_OUTPUT_SYMLINK", "publication output path contains a symbolic link") if stat.symlink?
          raise ContractError.new("inventory", "E_OUTPUT_NOT_DIRECTORY", "publication output path component is not a directory") unless stat.directory?
        elsif create_missing
          Dir.mkdir(cursor, 0o755)
        else
          raise ContractError.new("check", "E_OUTPUT_MISSING", "publication output parent is missing")
        end
      end
      cursor
    end

    def validate_existing_output!(output)
      stat = File.lstat(output)
      raise ContractError.new("inventory", "E_OUTPUT_SYMLINK", "profile output directory cannot be a symbolic link") if stat.symlink?
      raise ContractError.new("inventory", "E_OUTPUT_NOT_DIRECTORY", "profile output path must be a directory") unless stat.directory?
    end

    def validate_staged_tree!(staging, expected_content)
      entries = Dir.children(staging).sort
      unless entries == ["publication-plan.json"]
        raise ContractError.new("stage-validation", "E_STAGE_FILE_SET", "staged output does not match the exact R1-A file set")
      end
      path = File.join(staging, "publication-plan.json")
      stat = File.lstat(path)
      unless stat.file? && !stat.symlink?
        raise ContractError.new("stage-validation", "E_STAGE_UNSAFE", "staged plan is not a regular file")
      end
      unless Digest::SHA256.file(path).hexdigest == Digest::SHA256.hexdigest(expected_content)
        raise ContractError.new("stage-validation", "E_STAGE_DIGEST", "staged plan digest does not match expected bytes")
      end
    end

    def validate_profile_id!(profile_id)
      return if profile_id.is_a?(String) && /\A[a-z0-9]+(?:-[a-z0-9]+)*\z/.match?(profile_id)

      raise ContractError.new("schema", "E_PROFILE_ID", "profile id cannot determine a safe output directory")
    end

    def fsync_directory(directory)
      File.open(directory, File::RDONLY) { |dir| dir.fsync }
    rescue Errno::EINVAL, Errno::EISDIR
      nil
    end
  end
end
