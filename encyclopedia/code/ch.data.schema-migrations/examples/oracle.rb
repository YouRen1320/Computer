# frozen_string_literal: true

require "digest"
require "json"

ROOT = File.expand_path(__dir__)

def check(condition, message)
  raise "oracle-failure=#{message}" unless condition
end

manifest = JSON.parse(File.read(File.join(ROOT, "manifest.json")))
paths = JSON.parse(File.read(File.join(ROOT, "paths.json")))
versioned = manifest.fetch("versioned")
check(versioned.map { |item| item.fetch("version") } == %w[1 2 2.1 2.2 3], "numeric migration order")
check(versioned.map { |item| item.fetch("stage") } == %w[create expand backfill validate contract], "safe stages")

(versioned + manifest.fetch("repeatable")).each do |item|
  content = File.binread(File.join(ROOT, item.fetch("file")))
  check(Digest::SHA256.hexdigest(content) == item.fetch("sha256"), "immutable checksum #{item.fetch("file")}")
end

sql = versioned.to_h { |item| [item.fetch("version"), File.read(File.join(ROOT, item.fetch("file")))] }
check(sql.fetch("2").include?("ADD COLUMN priority_code") && sql.fetch("2").include?("NOT VALID"), "expand nullable")
check(sql.fetch("2.1").include?("WHERE priority_code IS NULL"), "resumable backfill condition")
check(sql.fetch("2.2").include?("VALIDATE CONSTRAINT"), "constraint validation")
check(sql.fetch("3").include?("SET NOT NULL") && sql.fetch("3").include?("DROP COLUMN priority"), "contract after validation")
repeatable = File.read(File.join(ROOT, manifest.fetch("repeatable").fetch(0).fetch("file")))
check(repeatable.include?("CREATE OR REPLACE VIEW"), "repeatable is replaceable")

empty = paths.fetch("empty_database")
upgrade = paths.fetch("v1_upgrade_database")
check(empty == upgrade, "empty and upgrade final state")
check(empty.fetch("remaining_nulls").zero? && empty.fetch("mismatches").zero?, "backfill data")
second = paths.fetch("second_migrate")
check(second.values == [0, 0, false], "second migrate is no-op")

puts "migration-order=1,2,2.1,2.2,3|stages=create,expand,backfill,validate,contract"
puts "checksums=versioned:5|repeatable:1|verdict=PASS"
puts "path-equivalence=empty:v1-upgrade|schema-and-data=PASS"
puts "second-migrate=pending:0|data-changes:0|verdict=PASS"
puts "schema-migrations-example=PASS"
