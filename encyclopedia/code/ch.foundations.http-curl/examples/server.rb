# frozen_string_literal: true

require_relative "local_http_server"

raw_port = ENV.fetch("PORT", "45678")
port = Integer(raw_port, 10)
abort "PORT must be between 1024 and 65535" unless port.between?(1024, 65_535)

server = LocalHttpServer.new(port: port)
trap("INT") { server.close; exit 0 }
trap("TERM") { server.close; exit 0 }

puts "FactoryCare teaching server: http://127.0.0.1:#{server.port}"
puts "Stop with Ctrl-C. This server accepts loopback requests only."
server.serve_forever
