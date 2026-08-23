# frozen_string_literal: true

# Expected values are literal decisions derived from the written billing rule.
# They never call the production calculator, which keeps the oracle independent.
TEST_CASES = [
  {
    name: "normal-two-blocks",
    arrange: { labor_minutes: 60, block_rate_cents: 5_000, parts_cents: 1_000 },
    expected: 11_000
  },
  {
    name: "zero-labor-keeps-parts",
    arrange: { labor_minutes: 0, block_rate_cents: 5_000, parts_cents: 1_250 },
    expected: 1_250
  },
  {
    name: "one-minute-starts-one-block",
    arrange: { labor_minutes: 1, block_rate_cents: 5_000, parts_cents: 0 },
    expected: 5_000
  },
  {
    name: "thirty-minutes-is-one-block",
    arrange: { labor_minutes: 30, block_rate_cents: 5_000, parts_cents: 0 },
    expected: 5_000
  },
  {
    name: "thirty-one-minutes-starts-two-blocks",
    arrange: { labor_minutes: 31, block_rate_cents: 5_000, parts_cents: 0 },
    expected: 10_000
  },
  {
    name: "maximum-labor-boundary",
    arrange: { labor_minutes: 1_440, block_rate_cents: 100, parts_cents: 0 },
    expected: 4_800
  },
  {
    name: "negative-labor-is-invalid",
    arrange: { labor_minutes: -1, block_rate_cents: 5_000, parts_cents: 0 },
    expected_error: ArgumentError
  },
  {
    name: "string-minutes-is-invalid",
    arrange: { labor_minutes: "30", block_rate_cents: 5_000, parts_cents: 0 },
    expected_error: ArgumentError
  }
].freeze
