# frozen_string_literal: true

require "pathname"
require "digest"

require_relative "contract"

module Verification
  # Resolves package-manager caches from explicit CLI overrides or dedicated
  # environment variables. Required caches never fall back to user defaults.
  class CachePolicy
    POLICY_ID = "explicit-fixed-cache-v1"
    DART_PUB_CONTENT_ROOTS = ["hosted", "hosted-hashes", "git/cache"].freeze
    DART_PUB_MUTABLE_ROOTS = %w[_temp active_roots log].freeze
    SPECS = {
      "dart-pub" => {
        key: :dart_pub_cache,
        variable: "FACTORYCARE_DART_PUB_CACHE"
      },
      "maven" => {
        key: :maven_repo,
        variable: "FACTORYCARE_MAVEN_REPO"
      },
      "pnpm" => {
        key: :pnpm_store,
        variable: "FACTORYCARE_PNPM_STORE_DIR"
      },
      "uv" => {
        key: :uv_cache,
        variable: "FACTORYCARE_UV_CACHE_DIR"
      }
    }.freeze

    attr_reader :root, :locations

    def self.resolve(root:, tool_ids:, overrides: {}, env: ENV)
      required = tool_ids.map(&:to_s).uniq.sort & SPECS.keys
      locations = required.to_h do |tool_id|
        spec = SPECS.fetch(tool_id)
        override = overrides[spec.fetch(:key)] || overrides[spec.fetch(:key).to_s]
        configured = present(override) || present(env[spec.fetch(:variable)])
        unless configured
          raise ContractError.new(
            "cache", "E_CACHE_REQUIRED",
            "required fixed cache is not configured; set #{spec.fetch(:variable)}",
            path: tool_id
          )
        end
        [tool_id, configured]
      end
      new(root: root, locations: locations)
    end

    def self.present(value)
      string = value&.to_s
      string unless string.nil? || string.empty?
    end
    private_class_method :present

    def initialize(root:, locations:)
      @root = File.realpath(root)
      @locations = locations.keys.sort.to_h do |tool_id|
        [tool_id, validate_location!(tool_id, locations.fetch(tool_id))]
      end.freeze
    end

    def execution_environment
      environment = {}
      if (path = locations["dart-pub"])
        environment["PUB_CACHE"] = path
      end
      if (path = locations["pnpm"])
        # pnpm 10 reads the npm namespace while pnpm 11 reads the pnpm
        # namespace. Set both to the same fixed store base; either single
        # namespace would silently make one CLI generation fall back to HOME.
        %w[npm_config pnpm_config].each do |prefix|
          environment["#{prefix}_store_dir"] = path
          environment["#{prefix}_offline"] = "true"
          environment["#{prefix}_reporter"] = "silent"
          environment["#{prefix}_manage_package_manager_versions"] = "false"
        end
        environment["pnpm_config_enable_global_virtual_store"] = "false"
        # The standalone pnpm binary otherwise mutates its private CLI cache to
        # auto-install packageManager versions. Audit the fixed installed CLI
        # instead; declared packageManager bytes remain in the static closure.
      end
      if (path = locations["uv"])
        environment["UV_CACHE_DIR"] = path
        environment["UV_OFFLINE"] = "1"
      end
      if (path = locations["maven"])
        environment["MAVEN_ARGS"] = "--offline --batch-mode --no-transfer-progress -Dmaven.repo.local=#{path}"
      end
      environment
    end

    def evidence_summary
      {
        "policy" => POLICY_ID,
        "network_mode" => "package-manager-offline-flags-or-entrypoint-offline-flags-not-os-enforced",
        "content_identity" => "location-only-in-this-summary; caller-must-record-bounded-pnpm-or-dart-pub-inventories-when-claimed",
        "configured" => locations.keys.sort.to_h do |tool_id|
          [tool_id, { "location_sha256" => Canonical.sha256(locations.fetch(tool_id).b) }]
        end
      }
    end

    # Hashes replay-relevant Dart Pub package bytes while deliberately
    # excluding state that `dart pub get --offline` is expected to rewrite.
    # The explicit root allowlist keeps an unexpected new cache subsystem from
    # being silently treated as frozen package content.
    def dart_pub_cache_inventory_summary
      path = locations.fetch("dart-pub")
      digest = Digest::SHA256.new
      file_count = 0
      directory_count = 0
      included = DART_PUB_CONTENT_ROOTS.select do |name|
        candidate = File.join(path, name)
        File.exist?(candidate) || File.symlink?(candidate)
      end
      included.each do |name|
        root_path = File.join(path, name)
        entries = [root_path] + Dir.glob(File.join(root_path, "**", "*"), File::FNM_DOTMATCH).sort
        entries.each do |absolute|
          relative = absolute.delete_prefix(path + File::SEPARATOR)
          next if relative.empty? || relative.split(File::SEPARATOR).any? { |part| part == "." || part == ".." }

          stat = File.lstat(absolute)
          digest << relative << "\0" << format("%04o", stat.mode & 0o777) << "\0"
          if stat.directory? && !stat.symlink?
            directory_count += 1
            digest << "directory\0"
          elsif stat.file? && !stat.symlink?
            bytes = File.binread(absolute)
            file_count += 1
            digest << "file\0" << bytes.bytesize.to_s << "\0" << Digest::SHA256.hexdigest(bytes) << "\0"
          else
            raise ContractError.new(
              "cache", "E_CACHE_INVENTORY_KIND",
              "Dart Pub package-content inventory contains a symbolic link or special entry", path: "dart-pub"
            )
          end
        end
      end
      {
        "policy" => "allowlisted-package-content-path-kind-mode-size-and-byte-digest-v1",
        "included_roots" => included,
        "excluded_mutable_roots" => DART_PUB_MUTABLE_ROOTS,
        "file_count" => file_count,
        "directory_count" => directory_count,
        "inventory_sha256" => digest.hexdigest
      }
    end

    # Captures a bounded, deterministic inventory of pnpm's package-content
    # and index inputs. Content-addressed file paths are already hashes; index
    # bytes are hashed explicitly. Mutable project-history directories are not
    # part of this replay input identity.
    def pnpm_store_inventory_summary
      path = locations.fetch("pnpm")
      digest = Digest::SHA256.new
      content_count = 0
      index_count = 0
      Dir.glob(File.join(path, "v*", "**", "*"), File::FNM_DOTMATCH).sort.each do |absolute|
        relative = absolute.delete_prefix(path + File::SEPARATOR)
        parts = relative.split(File::SEPARATOR)
        next if parts.any? { |part| part == "." || part == ".." }
        next unless parts[1] == "files" || parts[1] == "index" || parts[1] == "index.db"

        stat = File.lstat(absolute)
        next if stat.directory?
        unless stat.file? && !stat.symlink?
          raise ContractError.new(
            "cache", "E_CACHE_INVENTORY_KIND",
            "pnpm package-content inventory contains a symbolic link or special entry", path: "pnpm"
          )
        end
        kind = parts[1] == "files" ? "content" : "index"
        content_count += 1 if kind == "content"
        index_count += 1 if kind == "index"
        digest << relative << "\0" << kind << "\0" << format("%04o", stat.mode & 0o777) << "\0"
        digest << stat.size.to_s << "\0"
        digest << Digest::SHA256.file(absolute).hexdigest << "\0" if kind == "index"
      end
      {
        "policy" => "content-addressed-path-and-size-plus-index-byte-digest-v1",
        "content_file_count" => content_count,
        "index_file_count" => index_count,
        "inventory_sha256" => digest.hexdigest,
        "excluded_mutable_scope" => "projects-and-non-package-manager-state"
      }
    end

    private

    def validate_location!(tool_id, configured)
      value = configured.to_s
      if value.match?(/[\x00-\x20]/)
        raise ContractError.new("cache", "E_CACHE_PATH_CHARS", "cache path contains unsupported characters", path: tool_id)
      end
      unless Pathname(value).absolute?
        raise ContractError.new("cache", "E_CACHE_ABSOLUTE", "cache path must be absolute", path: tool_id)
      end

      reject_symlink_components!(tool_id, value)
      real = File.realpath(value)
      unless File.directory?(real)
        raise ContractError.new("cache", "E_CACHE_NOT_DIRECTORY", "cache path must be a directory", path: tool_id)
      end
      if contained?(real, root)
        raise ContractError.new("cache", "E_CACHE_IN_REPOSITORY", "cache path must be outside the repository", path: tool_id)
      end
      unless File.readable?(real) && File.writable?(real)
        raise ContractError.new("cache", "E_CACHE_PERMISSIONS", "cache directory must be readable and writable", path: tool_id)
      end
      real
    rescue Errno::ENOENT
      raise ContractError.new("cache", "E_CACHE_MISSING", "cache directory does not exist", path: tool_id)
    end

    def reject_symlink_components!(tool_id, value)
      cursor = File::SEPARATOR
      Pathname(value).each_filename do |component|
        cursor = File.join(cursor, component)
        break unless File.exist?(cursor) || File.symlink?(cursor)

        if File.lstat(cursor).symlink?
          raise ContractError.new("cache", "E_CACHE_SYMLINK", "cache path contains a symbolic link", path: tool_id)
        end
      end
    end

    def contained?(candidate, base)
      candidate == base || candidate.start_with?(base + File::SEPARATOR)
    end
  end
end
