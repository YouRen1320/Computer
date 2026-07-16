# frozen_string_literal: true

require_relative "local_network_lab"

report = LocalNetworkLab.run
normal = report.fetch("normal")
failures = report.fetch("failures")
by_name = failures.each_with_object({}) { |entry, memo| memo[entry.fetch(:name)] = entry }

abort "network-layers verification: FAIL: normal chain did not pass" unless normal.fetch(:ok)
abort "network-layers verification: FAIL: normal layer order changed" unless normal.fetch(:visited) == %w[dns tcp tls]
abort "network-layers verification: FAIL: TLS payload missing" unless normal.fetch(:facts).fetch("payload") == "FACTORYCARE-TLS-OK"

dns = by_name.fetch("invalid-hostname")
abort "network-layers verification: FAIL: DNS fault misclassified" unless dns.fetch(:failed_layer) == "dns"
abort "network-layers verification: FAIL: TCP ran after DNS failure" unless dns.fetch(:visited) == ["dns"]

tcp = by_name.fetch("closed-port")
abort "network-layers verification: FAIL: closed port misclassified" unless tcp.fetch(:failed_layer) == "tcp"
abort "network-layers verification: FAIL: TLS ran after TCP failure" unless tcp.fetch(:visited) == %w[dns tcp]

tls = by_name.fetch("certificate-name-mismatch")
abort "network-layers verification: FAIL: certificate mismatch misclassified" unless tls.fetch(:failed_layer) == "tls"
abort "network-layers verification: FAIL: TLS stage was not reached" unless tls.fetch(:visited) == %w[dns tcp tls]

timeout = report.fetch("timeout")
abort "network-layers verification: FAIL: timeout oracle changed" unless timeout.fetch("failed_layer") == "tcp-wait"

puts "normal: DNS -> TCP -> TLS -> trusted loopback payload"
puts "failure: invalid hostname stopped before TCP"
puts "failure: closed port stopped before TLS"
puts "failure: certificate hostname mismatch reached and failed at TLS"
puts "boundary: bounded local read wait expired after TCP connected"
puts "network-layers verification: PASS"
