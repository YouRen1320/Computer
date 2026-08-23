# frozen_string_literal: true

require "json"

def check(condition, message)
  raise "answer-error=#{message}" unless condition
end

answer = JSON.parse(File.read(ARGV.fetch(0))).fetch("decisions")
check(answer.keys.sort == %w[core-tags device-id device-status search-aliases serial-number vendor-metadata], "all six facts need decisions")
check(answer.fetch("device-id").fetch("choice") == "uuid", "device id must use native uuid")
check(answer.fetch("vendor-metadata").fetch("choice") == "jsonb-object", "JSONB is only for optional vendor metadata")
check(answer.fetch("search-aliases").fetch("choice") == "bounded-text-array", "small aliases need an explicit bound")
check(answer.fetch("core-tags").fetch("choice") == "relation-table", "core tags need keys and referential integrity")
check(answer.fetch("device-status").fetch("choice") == "text-check", "changing portable status uses text plus CHECK")
check(answer.fetch("serial-number").fetch("choice") == "asset-code-domain", "serial format belongs in the domain")
check(answer.values.all? { |item| !item.fetch("constraints").empty? }, "every choice needs enforceable constraints")
check(answer.values.all? { |item| item.fetch("portability") != "none" }, "every choice needs a portability plan")
puts "postgresql-types-answer=PASS"
