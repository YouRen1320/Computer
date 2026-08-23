# frozen_string_literal: true

require "base64"
require "digest"
require "json"

# Models API contracts in memory. It intentionally contains no router,
# authentication, database, or network code so learners can inspect semantics.
module ApiContractLab
  module_function

  def canonical_value(value)
    case value
    when Hash
      value.keys.sort.each_with_object({}) { |key, result| result[key] = canonical_value(value.fetch(key)) }
    when Array
      value.map { |item| canonical_value(item) }
    else
      value
    end
  end

  def canonical_json(value)
    JSON.generate(canonical_value(value))
  end

  def problem(status:, code:, title:, detail:, instance:)
    {
      "type" => "https://factorycare.example/problems/#{code}",
      "title" => title,
      "status" => status,
      "detail" => detail,
      "instance" => instance,
      "code" => code
    }
  end

  def unknown_internal_problem(instance:)
    problem(
      status: 500,
      code: "internal-error",
      title: "The request could not be completed",
      detail: "Use the public incident reference when contacting support.",
      instance: instance
    )
  end

  def device_representation(device, version: "v1")
    stable = {
      "id" => device.fetch("id"),
      "displayName" => device.fetch("display_name"),
      "status" => device.fetch("status")
    }
    return stable if version == "v1"
    return stable.merge("location" => device.fetch("location")) if version == "v1.1"

    raise ArgumentError, "unsupported representation version"
  end

  def compatible_addition?(old_representation, new_representation)
    old_representation.all? do |key, old_value|
      new_representation.key?(key) && new_representation.fetch(key) == old_value
    end
  end

  # Demonstrates a breaking rename for the diagnostic exercise.
  def broken_v2_representation(device)
    {
      "id" => device.fetch("id"),
      "name" => device.fetch("display_name"),
      "status" => device.fetch("status")
    }
  end

  class CursorPager
    def initialize(rows)
      @rows = rows.map(&:dup)
    end

    def insert(row)
      @rows << row.dup
    end

    def offset_page(offset:, limit:)
      ordered_rows.drop(offset).first(limit)
    end

    def cursor_page(after: nil, limit:)
      raise ArgumentError, "limit must be between 1 and 50" unless limit.is_a?(Integer) && limit.between?(1, 50)

      eligible = ordered_rows
      if after
        boundary = decode_cursor(after)
        eligible = eligible.select { |row| (sort_key(row) <=> boundary).negative? }
      end

      items = eligible.first(limit)
      has_more = eligible.length > items.length
      {
        "items" => items,
        "nextCursor" => has_more ? encode_cursor(sort_key(items.last)) : nil
      }
    rescue ArgumentError, JSON::ParserError
      {
        "items" => [],
        "nextCursor" => nil,
        "problem" => ApiContractLab.problem(
          status: 400,
          code: "invalid-cursor",
          title: "Pagination cursor is invalid",
          detail: "Restart pagination without an after cursor.",
          instance: "/problems/PAGE-001"
        )
      }
    end

    def cursor_for(row)
      encode_cursor(sort_key(row))
    end

    private

    def ordered_rows
      @rows.sort { |left, right| sort_key(right) <=> sort_key(left) }
    end

    def sort_key(row)
      [row.fetch("createdAt"), row.fetch("id")]
    end

    def encode_cursor(key)
      Base64.strict_encode64(JSON.generate(key))
    end

    def decode_cursor(token)
      value = JSON.parse(Base64.strict_decode64(token))
      unless value.is_a?(Array) && value.length == 2 && value.all? { |part| part.is_a?(String) }
        raise ArgumentError, "invalid cursor shape"
      end

      value
    end
  end

  class CacheContract
    def initialize(device)
      @device = device
    end

    def get(if_none_match: nil)
      body = ApiContractLab.device_representation(@device, version: "v1")
      tag = %Q("#{Digest::SHA256.hexdigest(ApiContractLab.canonical_json(body))}")
      return { "status" => 304, "headers" => { "ETag" => tag }, "body" => nil } if if_none_match == tag

      {
        "status" => 200,
        "headers" => { "ETag" => tag, "Content-Type" => "application/json" },
        "body" => body
      }
    end
  end

  class WorkOrderCreator
    attr_reader :records

    def initialize
      @records = []
      @idempotency = {}
    end

    def unsafe_create(payload)
      create_record(payload).merge("replayed" => false)
    end

    def create(payload, idempotency_key:)
      if !idempotency_key.is_a?(String) || idempotency_key.empty?
        return {
          "status" => 400,
          "body" => ApiContractLab.problem(
            status: 400,
            code: "idempotency-key-required",
            title: "An idempotency key is required",
            detail: "Send one stable key for every logical create operation.",
            instance: "/problems/WRITE-001"
          )
        }
      end

      fingerprint = Digest::SHA256.hexdigest(ApiContractLab.canonical_json(payload))
      previous = @idempotency[idempotency_key]
      if previous
        return conflict(idempotency_key) unless previous.fetch("fingerprint") == fingerprint

        return { "status" => 201, "body" => previous.fetch("body").merge("replayed" => true) }
      end

      body = create_record(payload).merge("replayed" => false)
      @idempotency[idempotency_key] = { "fingerprint" => fingerprint, "body" => body }
      { "status" => 201, "body" => body }
    end

    private

    def create_record(payload)
      record = {
        "id" => format("FC-%04d", 2001 + @records.length),
        "deviceId" => payload.fetch("deviceId"),
        "summary" => payload.fetch("summary")
      }
      @records << record
      record
    end

    def conflict(key)
      {
        "status" => 409,
        "body" => ApiContractLab.problem(
          status: 409,
          code: "idempotency-key-conflict",
          title: "The idempotency key was already used",
          detail: "Reuse a key only with the original request content.",
          instance: "/problems/#{Digest::SHA256.hexdigest(key)[0, 12]}"
        )
      }
    end
  end
end
