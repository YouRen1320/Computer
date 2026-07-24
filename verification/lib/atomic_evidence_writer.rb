# frozen_string_literal: true

require "fileutils"

require_relative "contract"

module Verification
  # The previous successful evidence tree remains visible until a complete new
  # tree has been written, checked, fsynced, and promoted by rename.
  class AtomicEvidenceWriter
    attr_reader :root, :renamer, :evidence_directory

    def initialize(root, renamer: nil, evidence_directory: EVIDENCE_DIRECTORY)
      @root = File.realpath(root)
      @renamer = renamer || lambda { |source, destination| File.rename(source, destination) }
      unless [EVIDENCE_DIRECTORY, PRIVATE_EVIDENCE_DIRECTORY].include?(evidence_directory)
        raise ArgumentError, "unsupported evidence directory"
      end
      @evidence_directory = evidence_directory
    end

    def write(bytes)
      parent = prepare_parent
      output = File.join(root, evidence_directory)
      token = "#{$$}-#{rand(1_000_000)}"
      staging = File.join(parent, ".last-run.stage-#{token}")
      backup = File.join(parent, ".last-run.backup-#{token}")
      [staging, backup].each do |path|
        if File.exist?(path) || File.symlink?(path)
          raise ContractError.new("commit", "E_TEMP_EXISTS", "temporary evidence path already exists")
        end
      end

      staging_exists = false
      backup_exists = false
      committed = false
      preserve_recovery = false
      begin
        Dir.mkdir(staging, 0o755)
        staging_exists = true
        evidence_path = File.join(staging, "evidence.json")
        File.open(evidence_path, File::WRONLY | File::CREAT | File::EXCL, 0o644) do |file|
          file.binmode
          file.write(bytes)
          file.flush
          file.fsync
        end
        validate_staging!(staging, bytes)
        fsync_directory(staging)

        if File.exist?(output) || File.symlink?(output)
          validate_existing_output!(output)
          renamer.call(output, backup)
          backup_exists = true
        end

        begin
          renamer.call(staging, output)
          staging_exists = false
        rescue StandardError => promotion_error
          raise if promotion_error.is_a?(ContractError)

          if backup_exists
            begin
              renamer.call(backup, output)
              backup_exists = false
              fsync_directory(parent)
            rescue StandardError
              preserve_recovery = true
              raise ContractError.new(
                "rollback", "E_ROLLBACK_FAILED",
                "evidence promotion failed and recovery trees were preserved"
              )
            end
          end
          raise ContractError.new(
            "commit", "E_ATOMIC_PROMOTION",
            "evidence promotion failed; the previous tree was restored (#{promotion_error.class})"
          )
        end

        begin
          fsync_directory(parent)
          committed = true
        rescue StandardError => durability_error
          begin
            renamer.call(output, staging)
            staging_exists = true
            if backup_exists
              renamer.call(backup, output)
              backup_exists = false
            end
            fsync_directory(parent)
          rescue StandardError
            preserve_recovery = true
            raise ContractError.new(
              "rollback", "E_ROLLBACK_FAILED",
              "evidence durability sync failed and recovery trees were preserved"
            )
          end
          raise ContractError.new(
            "commit", "E_ATOMIC_DURABILITY",
            "evidence durability sync failed; the previous tree was restored (#{durability_error.class})"
          )
        end

        if backup_exists && File.directory?(backup) && !File.symlink?(backup)
          FileUtils.rm_rf(backup)
          backup_exists = false unless File.exist?(backup) || File.symlink?(backup)
        end
      rescue ContractError
        raise
      rescue StandardError => e
        raise ContractError.new("commit", "E_ATOMIC_COMMIT", "atomic evidence commit failed (#{e.class})")
      ensure
        unless preserve_recovery
          FileUtils.rm_rf(staging) if staging_exists && File.directory?(staging) && !File.symlink?(staging)
          if committed && File.directory?(backup) && !File.symlink?(backup)
            FileUtils.rm_rf(backup)
          end
        end
      end
      File.join(evidence_directory, "evidence.json")
    end

    private

    def prepare_parent
      cursor = root
      File.dirname(evidence_directory).split("/").each do |component|
        cursor = File.join(cursor, component)
        if File.exist?(cursor) || File.symlink?(cursor)
          stat = File.lstat(cursor)
          raise ContractError.new("commit", "E_EVIDENCE_SYMLINK", "evidence path contains a symbolic link") if stat.symlink?
          raise ContractError.new("commit", "E_EVIDENCE_NOT_DIRECTORY", "evidence path is not a directory") unless stat.directory?
        else
          Dir.mkdir(cursor, 0o755)
        end
      end
      cursor
    end

    def validate_existing_output!(output)
      stat = File.lstat(output)
      raise ContractError.new("commit", "E_EVIDENCE_SYMLINK", "existing evidence tree cannot be a symbolic link") if stat.symlink?
      raise ContractError.new("commit", "E_EVIDENCE_NOT_DIRECTORY", "existing evidence tree must be a directory") unless stat.directory?
    end

    def validate_staging!(staging, expected_bytes)
      unless Dir.children(staging).sort == ["evidence.json"]
        raise ContractError.new("stage-validation", "E_EVIDENCE_FILE_SET", "staged evidence must contain exactly evidence.json")
      end
      path = File.join(staging, "evidence.json")
      stat = File.lstat(path)
      unless stat.file? && !stat.symlink? && File.binread(path) == expected_bytes.b
        raise ContractError.new("stage-validation", "E_EVIDENCE_BYTES", "staged evidence bytes differ from the validated report")
      end
    end

    def fsync_directory(directory)
      File.open(directory, File::RDONLY) { |dir| dir.fsync }
    rescue Errno::EINVAL, Errno::EISDIR
      nil
    end
  end
end
