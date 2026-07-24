# frozen_string_literal: true

require_relative "contract"

module Verification
  # Validates deterministic machine-only reports before they are persisted.
  # A successful schema check is structural evidence, never human promotion.
  module MachineReportSchema
    module_function

    def validate!(root:, schema_path:, document:)
      guard = PathGuard.new(root)
      bytes, = guard.read_contract(schema_path)
      schema = StrictJson.parse(bytes)
      evaluator = ExecutableJsonSchema.new(schema, schema_path)
      unless evaluator.definition_errors.empty?
        raise ContractError.new(
          "machine-report-schema", "E_MACHINE_SCHEMA_DEFINITION",
          evaluator.definition_errors.first, path: schema_path
        )
      end
      errors = evaluator.validate(document)
      return document if errors.empty?

      raise ContractError.new(
        "machine-report-schema", "E_MACHINE_REPORT_SCHEMA",
        errors.first, path: schema_path
      )
    rescue StrictJson::DuplicateMemberError, JSON::ParserError => e
      raise ContractError.new(
        "machine-report-schema", "E_MACHINE_SCHEMA_JSON",
        e.message.lines.first.to_s.strip, path: schema_path
      )
    end
  end
end
