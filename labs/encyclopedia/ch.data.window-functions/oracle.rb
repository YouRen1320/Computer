# frozen_string_literal: true

require "csv"
require "json"
require "time"

ROOT = File.expand_path(__dir__)

def check(condition, message)
  raise "lab-failure=#{message}" unless condition
end

sql = File.read(File.join(ROOT, "query.sql"))
check(sql.scan("PARTITION BY w.technician_id").length == 6, "all correct windows partitioned")
check(sql.scan("ORDER BY w.created_at, w.work_order_id").length == 6, "all correct windows stably ordered")
check(sql.include?("ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW"), "explicit ROWS frame")
check(sql.include?("ORDER BY w.technician_id, w.created_at, w.work_order_id;"), "final order")

scenarios = JSON.parse(File.read(File.join(ROOT, "scenarios.json")))
check(scenarios.map { |item| item.fetch("id") } == %w[missing-partition nonunique-window-order default-peer-frame], "scenario ids")

rows = CSV.read(File.join(ROOT, "work_orders.csv"), headers: true).map do |row|
  {
    "id" => row["work_order_id"],
    "technician" => row["technician_id"],
    "created_at" => Time.iso8601(row["created_at"]),
    "status" => row["status"]
  }
end

global = rows.sort_by { |row| [row["created_at"], row["id"]] }.each_with_index.map do |row, index|
  [row["id"], row["technician"], index + 1]
end
global_starts = global.group_by { |_id, technician, _sequence| technician }.map do |technician, part|
  [technician, part.map(&:last).min]
end.sort

correct = []
default_range = []
peer_groups = []
rows.group_by { |row| row["technician"] }.sort.each do |technician, partition|
  ordered = partition.sort_by { |row| [row["created_at"], row["id"]] }
  completed = 0
  ordered.each_with_index do |row, index|
    completed += 1 if row["status"] == "CLOSED"
    correct << [technician, row["id"], index + 1, completed]
    peer_total = ordered.count { |candidate| candidate["status"] == "CLOSED" && candidate["created_at"] <= row["created_at"] }
    default_range << [technician, row["id"], peer_total]
  end
  partition.group_by { |row| row["created_at"] }.each_value do |peers|
    peer_groups << [technician, peers.first["created_at"], peers.map { |row| row["id"] }.sort] if peers.length > 1
  end
end

correct_starts = correct.group_by { |technician, _id, _seq, _done| technician }.map do |technician, part|
  [technician, part.map { |_tech, _id, sequence, _done| sequence }.min]
end.sort

check(rows.length == 6 && correct.length == rows.length, "row preservation")
check(correct_starts == [["T-01", 1], ["T-02", 1]], "partition starts")
check(global_starts == [["T-01", 2], ["T-02", 1]], "missing partition evidence")
check(peer_groups.map { |_tech, _time, peers| peers } == [%w[W-01 W-02], %w[W-05 W-06]], "ambiguous peer groups")
check(correct.map { |_tech, _id, _seq, done| done } == [0, 1, 2, 1, 1, 2], "explicit ROWS values")
check(default_range.map { |_tech, _id, done| done } == [1, 1, 2, 1, 2, 2], "default peer frame values")

puts "input-rows=#{rows.length}"
puts "output-rows=#{correct.length}"
puts "correct-partition-starts=#{correct_starts.map { |technician, sequence| "#{technician}:#{sequence}" }.join(",")}"
puts "missing-partition-starts=#{global_starts.map { |technician, sequence| "#{technician}:#{sequence}" }.join(",")}"
puts "missing-partition-sequences=#{global.map { |id, _technician, sequence| "#{id}:#{sequence}" }.join(",")}"
puts "ambiguous-peer-groups=#{peer_groups.map { |technician, _time, peers| "#{technician}:#{peers.join("/")}" }.join(",")}"
puts "stable-tiebreakers=T-01:W-01<W-02,T-02:W-05<W-06"
puts "explicit-rows-running=#{correct.map { |_tech, id, _seq, done| "#{id}:#{done}" }.join(",")}"
puts "default-range-running=#{default_range.map { |_tech, id, done| "#{id}:#{done}" }.join(",")}"
puts "first-frame-divergence=W-01:explicit-0/default-1"
puts "window-functions-lab=PASS"
