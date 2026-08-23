# frozen_string_literal: true

# Calculates a deterministic teaching quote in integer cents. Labor is billed
# in started 30-minute blocks; validation rules are part of the public oracle.
module WorkOrderAmount
  MAX_LABOR_MINUTES = 1_440
  MAX_BLOCK_RATE_CENTS = 1_000_000
  MAX_PARTS_CENTS = 10_000_000

  module_function

  def quote(labor_minutes:, block_rate_cents:, parts_cents:)
    validate_inputs!(labor_minutes, block_rate_cents, parts_cents)
    blocks = labor_minutes.zero? ? 0 : (labor_minutes + 29) / 30
    blocks * block_rate_cents + parts_cents
  end

  def validate_inputs!(labor_minutes, block_rate_cents, parts_cents)
    values = [labor_minutes, block_rate_cents, parts_cents]
    raise ArgumentError, "all amounts must be integers" unless values.all? { |value| value.is_a?(Integer) }
    raise ArgumentError, "labor_minutes is out of range" unless labor_minutes.between?(0, MAX_LABOR_MINUTES)
    raise ArgumentError, "block_rate_cents is out of range" unless block_rate_cents.between?(0, MAX_BLOCK_RATE_CENTS)
    raise ArgumentError, "parts_cents is out of range" unless parts_cents.between?(0, MAX_PARTS_CENTS)
  end
end
