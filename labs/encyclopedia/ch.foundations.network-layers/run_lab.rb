# frozen_string_literal: true

require "json"
require File.expand_path(
  "../../../examples/encyclopedia/ch.foundations.network-layers/local_network_lab",
  __dir__
)

report = LocalNetworkLab.run

puts "=== 先把下面结果与 worksheet.md 中的预测比较 ==="
puts JSON.pretty_generate(report)
puts
puts "请记录每个场景的 visited、failed_layer 与第一条可信错误证据。"
