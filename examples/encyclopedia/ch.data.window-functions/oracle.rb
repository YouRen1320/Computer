# frozen_string_literal: true

require "csv"
require "time"

ROOT = File.expand_path(__dir__)

def check(condition, message)
  raise "oracle-failure=#{message}" unless condition
end

sql = File.read(File.join(ROOT, "query.sql"))
check(sql.include?("ROW_NUMBER() OVER ("), "row_number")
check(sql.include?("LAG(w.work_order_id) OVER ("), "previous id")
check(sql.include?("LEAD(w.work_order_id) OVER ("), "next id")
check(sql.include?("w.created_at - LAG(w.created_at) OVER ("), "previous interval")
check(sql.include?("LEAD(w.created_at) OVER ("), "next interval")
check(sql.scan("PARTITION BY w.technician_id").length == 6, "all windows partitioned")
check(sql.scan("ORDER BY w.created_at, w.work_order_id").length == 6, "all windows stably ordered")
check(sql.include?("ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW"), "explicit running frame")
check(sql.include?("ORDER BY w.technician_id, w.created_at, w.work_order_id;"), "final display order")

rows = CSV.read(File.join(ROOT, "work_orders.csv"), headers: true).map do |row|
  {
    "id" => row["work_order_id"],
    "technician" => row["technician_id"],
    "created_at" => Time.iso8601(row["created_at"]),
    "status" => row["status"]
  }
end

output = []
rows.group_by { |row| row["technician"] }.sort.each do |technician, partition|
  ordered = partition.sort_by { |row| [row["created_at"], row["id"]] }
  completed = 0
  ordered.each_with_index do |row, index|
    previous = index.zero? ? nil : ordered[index - 1]
    following = index == ordered.length - 1 ? nil : ordered[index + 1]
    completed += 1 if row["status"] == "CLOSED"
    output << {
      "technician" => technician,
      "id" => row["id"],
      "sequence" => index + 1,
      "previous" => previous && previous["id"],
      "next" => following && following["id"],
      "since" => previous && (row["created_at"] - previous["created_at"]).to_i,
      "until" => following && (following["created_at"] - row["created_at"]).to_i,
      "completed" => completed
    }
  end
end

check(rows.length == 6 && output.length == rows.length, "detail row preservation")
starts = output.group_by { |row| row["technician"] }.map { |technician, part| [technician, part.first["sequence"]] }.sort
check(starts == [["T-01", 1], ["T-02", 1]], "partition sequence starts")
check(output.map { |row| row["completed"] } == [0, 1, 2, 1, 1, 2], "running completion values")
check(output.map { |row| row["since"] } == [nil, 0, 3600, nil, 5400, 0], "previous intervals")
check(output.map { |row| row["until"] } == [0, 3600, nil, 5400, 0, nil], "next intervals")

value = ->(item) { item.nil? ? "NULL" : item }
puts "input-rows=#{rows.length}"
puts "output-rows=#{output.length}"
output.each do |row|
  puts [
    row["technician"], row["id"], "seq=#{row["sequence"]}",
    "prev=#{value.call(row["previous"])}", "next=#{value.call(row["next"])}",
    "since=#{value.call(row["since"])}", "until=#{value.call(row["until"])}",
    "done=#{row["completed"]}"
  ].join("|")
end
puts "partition-starts=#{starts.map { |technician, sequence| "#{technician}:#{sequence}" }.join(",")}"
puts "stable-tiebreaker=W-01<W-02,W-05<W-06"
puts "window-functions-example=PASS"
