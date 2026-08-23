# frozen_string_literal: true

require "json"
require "open3"
require "tmpdir"
require_relative "local_http_server"

CaseResult = Struct.new(:name, :curl_exit, :http_status, :content_type, :time_total, :headers, :body, :stderr, keyword_init: true)

def request(base_url, dir, name, extra_args)
  header_path = File.join(dir, "#{name}.headers")
  body_path = File.join(dir, "#{name}.body")
  format = "%{http_code}\t%{content_type}\t%{time_total}"
  command = [
    "curl", "--noproxy", "*", "--silent", "--show-error",
    "--dump-header", header_path,
    "--output", body_path,
    "--write-out", format
  ] + extra_args + [base_url]

  stdout, stderr, status = Open3.capture3(*command)
  http_status, content_type, time_total = stdout.split("\t", -1)
  CaseResult.new(
    name: name,
    curl_exit: status.exitstatus,
    http_status: http_status,
    content_type: content_type,
    time_total: time_total,
    headers: File.exist?(header_path) ? File.read(header_path) : "",
    body: File.exist?(body_path) ? File.read(body_path) : "",
    stderr: stderr
  )
end

server = LocalHttpServer.new
thread = server.serve_in_thread(max_requests: 6)
base = "http://127.0.0.1:#{server.port}"

begin
  Dir.mktmpdir("factorycare-http-curl-") do |dir|
    ok = request("#{base}/api/work-orders/FC-1001", dir, "get-200", ["--request", "GET"])
    created = request(
      "#{base}/api/work-orders", dir, "post-201",
      ["--request", "POST", "--header", "Content-Type: application/json", "--data-binary", '{"deviceId":"PUMP-01"}']
    )
    missing = request("#{base}/missing", dir, "missing-404", ["--request", "GET"])
    unavailable = request("#{base}/explode", dir, "server-503", ["--request", "GET"])
    wrong_type = request(
      "#{base}/api/work-orders", dir, "wrong-type-415",
      ["--request", "POST", "--header", "Content-Type: text/plain", "--data-binary", '{"deviceId":"PUMP-01"}']
    )
    timeout = request("#{base}/slow", dir, "timeout", ["--request", "GET", "--max-time", "0.10"])

    abort "http-curl verification: FAIL: GET status" unless ok.http_status == "200" && ok.curl_exit.zero?
    abort "http-curl verification: FAIL: GET media type" unless ok.content_type.start_with?("application/json")
    abort "http-curl verification: FAIL: GET JSON" unless JSON.parse(ok.body).fetch("id") == "FC-1001"

    abort "http-curl verification: FAIL: POST status" unless created.http_status == "201" && created.curl_exit.zero?
    abort "http-curl verification: FAIL: Location header" unless created.headers.match?(/^Location: \/api\/work-orders\/FC-2001\r?$/i)

    abort "http-curl verification: FAIL: 404 must be classified by status" unless missing.http_status == "404"
    abort "http-curl verification: FAIL: default curl should complete a received 404" unless missing.curl_exit.zero?
    abort "http-curl verification: FAIL: problem JSON media type" unless missing.content_type.start_with?("application/problem+json")
    abort "http-curl verification: FAIL: problem JSON body" unless JSON.parse(missing.body).fetch("code") == "not-found"

    abort "http-curl verification: FAIL: 503 status" unless unavailable.http_status == "503" && unavailable.curl_exit.zero?
    abort "http-curl verification: FAIL: text body must remain text" unless unavailable.content_type.start_with?("text/plain")
    begin
      JSON.parse(unavailable.body)
      abort "http-curl verification: FAIL: text body was incorrectly accepted as JSON"
    rescue JSON::ParserError
      nil
    end

    abort "http-curl verification: FAIL: wrong request Content-Type" unless wrong_type.http_status == "415"
    abort "http-curl verification: FAIL: 415 response media type" unless wrong_type.content_type.start_with?("text/plain")

    abort "http-curl verification: FAIL: timeout exit code" unless timeout.curl_exit == 28
    abort "http-curl verification: FAIL: timeout fabricated an HTTP status" unless timeout.http_status == "000"
    abort "http-curl verification: FAIL: timeout stderr missing" if timeout.stderr.strip.empty?

    puts "2xx: GET=200 JSON; POST=201 JSON with Location"
    puts "4xx: 404 problem+json and 415 text/plain classified by HTTP status"
    puts "5xx: 503 text/plain received; default curl transfer exit remained 0"
    puts "media type: JSON parsed only for application/json or application/problem+json"
    puts "transport failure: /slow curl_exit=28 http_status=000 stderr=present"
    puts "http-curl verification: PASS"
  end
ensure
  thread.join(2) rescue nil
  server.close rescue nil
  thread.kill if thread&.alive?
end
