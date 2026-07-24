# frozen_string_literal: true

require "csv"
require "find"

# Guards the teaching repository against presenting a convenience status as a
# real FactoryCare WorkOrder status. Deliberately reduced DemoTicket models may
# use a canonical subset; only the Java-owned WorkOrder contract owns business
# status values.
module FactoryCareStatusContract
  CANONICAL_STATUSES = %w[
    CREATED TRIAGED ASSIGNED ACCEPTED IN_PROGRESS PENDING_PARTS
    PENDING_APPROVAL RESOLVED VERIFIED CLOSED REOPENED CANCELLED
  ].freeze
  FORBIDDEN_LEGACY_STATUSES = %w[NEW OPEN DONE COMPLETED].freeze
  SCAN_ROOTS = %w[
    book curriculum/chapters examples/encyclopedia labs/encyclopedia
    exercises/encyclopedia solutions-private/encyclopedia
  ].freeze
  TEXT_EXTENSIONS = %w[
    .csv .dart .html .java .js .json .jsx .kt .kts .md .mjs .py .rb
    .sql .ts .tsx .txt .vue .xml .yaml .yml
  ].freeze
  GENERATED_COMPONENTS = %w[
    .git .gradle .idea .mvn .venv build coverage dist node_modules target
  ].freeze
  UI_GROUP_MARKER = "FACTORYCARE_UI_GROUP: COMPLETED <- VERIFIED|CLOSED".freeze

  module_function

  def validate(root)
    absolute_root = File.realpath(root)
    errors = []
    scanned = 0

    candidate_files(absolute_root).each do |path|
      relative = relative_path(absolute_root, path)
      source = File.binread(path).force_encoding(Encoding::UTF_8)
      next unless source.valid_encoding?
      next unless work_order_context?(relative, source)

      scanned += 1
      errors.concat(validate_status_declarations(relative, source))
      errors.concat(validate_status_lines(relative, source))
      errors.concat(validate_status_csv(relative, source)) if File.extname(relative) == ".csv"
    end

    { errors: errors.uniq.sort, scanned_files: scanned }
  end

  def candidate_files(root)
    SCAN_ROOTS.flat_map do |relative_root|
      base = File.join(root, relative_root)
      next [] unless File.directory?(base)

      files = []
      Find.find(base) do |path|
        stat = File.lstat(path)
        if stat.symlink?
          Find.prune if stat.directory?
          next
        end
        if stat.directory?
          Find.prune if path != base && GENERATED_COMPONENTS.include?(File.basename(path))
          next
        end
        files << path if stat.file? && TEXT_EXTENSIONS.include?(File.extname(path))
      end
      files
    end.sort
  end

  def work_order_context?(relative, source)
    relative.match?(/work[-_]?order/i) ||
      source.match?(/\bWorkOrder(?:Status)?\b|\bwork_order\b|\bwork-order\b|\bwork order\b|工单/i)
  end

  def validate_status_declarations(relative, source)
    errors = []

    if source.match?(/\benum\s+(?:WorkOrderStatus|Status|State)\s*\{/)
      source.scan(/\benum\s+(WorkOrderStatus|Status|State)\s*\{([^}]*)\}/m) do |name, body|
        constants = body.split(";", 2).first.scan(/\b[A-Z][A-Z0-9_]*\b/).uniq
        invalid = constants - CANONICAL_STATUSES
        next if invalid.empty?

        errors << "#{relative}: #{name} declares non-canonical WorkOrder status(es): #{invalid.join(', ')}"
      end
    end

    if source.include?("type WorkOrderStatus")
      source.scan(/\b(?:export\s+)?type\s+WorkOrderStatus\s*=\s*([^;\n]+)/) do |match|
        constants = match.first.scan(/[\"']([A-Z][A-Z0-9_]*)[\"']/).flatten.uniq
        invalid = constants - CANONICAL_STATUSES
        next if invalid.empty?

        errors << "#{relative}: WorkOrderStatus declares non-canonical value(s): #{invalid.join(', ')}"
      end
    end

    errors
  end

  def validate_status_lines(relative, source)
    errors = []
    source.each_line.with_index(1) do |line, number|
      FORBIDDEN_LEGACY_STATUSES.each do |token|
        next unless line.include?(token)
        next unless forbidden_status_literal?(line, token)
        next if allowed_ui_group?(relative, source, line, token)

        errors << "#{relative}:#{number}: non-canonical WorkOrder status #{token}"
      end
    end
    errors
  end

  def forbidden_status_literal?(line, token)
    literal = /[\"']#{Regexp.escape(token)}[\"']/
    status_near_literal = /(?i:\bstatus\b).{0,120}#{literal}|#{literal}.{0,120}(?i:\bstatus\b)/
    qualified_constant = /(?<![.[:alnum:]_])(?:WorkOrderStatus|Status|State)\s*[.:]\s*#{Regexp.escape(token)}\b/
    option_value = /(?i:\bvalue)\s*=\s*[\"']#{Regexp.escape(token)}[\"']/
    query_value = /(?i:\bstatus)\s*=\s*#{Regexp.escape(token)}\b/
    transition_summary = /\bCHANGE_SUMMARY\b.{0,160}\b#{Regexp.escape(token)}\b/

    line.match?(status_near_literal) || line.match?(qualified_constant) ||
      line.match?(option_value) || line.match?(query_value) || line.match?(transition_summary)
  end

  def allowed_ui_group?(relative, source, line, token)
    return false unless token == "COMPLETED"

    if File.extname(relative) == ".md"
      return line.include?("UI") && line.match?(/展示分组|display group/i)
    end

    source.include?(UI_GROUP_MARKER) && line.match?(/\bgroup\s*:\s*[\"']COMPLETED[\"']/)
  end

  def validate_status_csv(relative, source)
    rows = CSV.parse(source)
    return [] if rows.empty?

    status_indexes = rows.first.each_index.select { |index| rows.first[index].to_s.match?(/status/i) }
    return [] if status_indexes.empty?

    errors = []
    rows.drop(1).each_with_index do |row, row_index|
      status_indexes.each do |column_index|
        token = row[column_index].to_s
        next unless FORBIDDEN_LEGACY_STATUSES.include?(token)

        errors << "#{relative}:#{row_index + 2}: non-canonical WorkOrder status #{token}"
      end
    end
    errors
  rescue CSV::MalformedCSVError => error
    ["#{relative}: cannot inspect WorkOrder status CSV: #{error.message}"]
  end

  def relative_path(root, path)
    path.delete_prefix(root + File::SEPARATOR)
  end
end
