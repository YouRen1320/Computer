# frozen_string_literal: true

require "json"
require "socket"

# A deliberately small HTTP/1.1 teaching server. It binds only to loopback and
# exposes fixed responses so curl observations remain deterministic.
class LocalHttpServer
  attr_reader :host, :port

  def initialize(host: "127.0.0.1", port: 0)
    @host = host
    @server = TCPServer.new(host, port)
    @port = @server.addr[1]
    @closed = false
  end

  def serve_in_thread(max_requests:)
    Thread.new do
      max_requests.times do
        break if @closed

        client = @server.accept
        handle(client)
      rescue IOError, Errno::EBADF
        break
      end
    end
  end

  def serve_forever
    loop do
      client = @server.accept
      handle(client)
    end
  rescue Interrupt
    nil
  ensure
    close
  end

  def close
    return if @closed

    @closed = true
    @server.close
  end

  private

  def handle(client)
    request_line = client.gets("\r\n")
    return unless request_line

    method, target, _version = request_line.strip.split(" ", 3)
    headers = {}
    while (line = client.gets("\r\n"))
      break if line == "\r\n"

      name, value = line.split(":", 2)
      headers[name.to_s.downcase] = value.to_s.strip
    end
    length = Integer(headers.fetch("content-length", "0"), 10)
    body = length.positive? ? client.read(length) : ""

    status, response_headers, response_body = route(method, target, headers, body)
    write_response(client, status, response_headers, response_body, method == "HEAD")
  rescue ArgumentError
    write_response(client, 400, { "Content-Type" => "text/plain; charset=utf-8" }, "invalid content length\n", false)
  rescue Errno::EPIPE, Errno::ECONNRESET, IOError
    # The /slow client intentionally times out and closes before this write.
  ensure
    client.close rescue nil
  end

  def route(method, target, headers, body)
    case [method, target]
    when ["GET", "/api/work-orders/FC-1001"]
      json(200, id: "FC-1001", status: "ASSIGNED", priority: "HIGH")
    when ["POST", "/api/work-orders"]
      return text(415, "expected application/json\n") unless json_content_type?(headers["content-type"])

      begin
        input = JSON.parse(body)
      rescue JSON::ParserError
        return problem(400, "invalid-json", "request body is not valid JSON")
      end
      return problem(400, "missing-device-id", "deviceId is required") unless input["deviceId"].is_a?(String) && !input["deviceId"].empty?

      status, response_headers, response_body = json(201, id: "FC-2001", deviceId: input["deviceId"], status: "REPORTED")
      response_headers["Location"] = "/api/work-orders/FC-2001"
      [status, response_headers, response_body]
    when ["GET", "/missing"]
      problem(404, "not-found", "the requested teaching resource does not exist")
    when ["GET", "/explode"]
      text(503, "maintenance window\n")
    when ["GET", "/slow"]
      sleep 0.5
      json(200, status: "late")
    else
      problem(404, "not-found", "no route matches method and target")
    end
  end

  def json_content_type?(value)
    value.to_s.split(";", 2).first.to_s.strip.downcase == "application/json"
  end

  def json(status, value)
    [status, { "Content-Type" => "application/json" }, JSON.generate(value) + "\n"]
  end

  def problem(status, code, detail)
    body = JSON.generate(type: "about:blank", code: code, detail: detail) + "\n"
    [status, { "Content-Type" => "application/problem+json" }, body]
  end

  def text(status, body)
    [status, { "Content-Type" => "text/plain; charset=utf-8" }, body]
  end

  def write_response(client, status, headers, body, head_only)
    reason = {
      200 => "OK",
      201 => "Created",
      400 => "Bad Request",
      404 => "Not Found",
      415 => "Unsupported Media Type",
      503 => "Service Unavailable"
    }.fetch(status)
    response_headers = {
      "Content-Length" => body.bytesize.to_s,
      "Connection" => "close",
      "Cache-Control" => "no-store"
    }.merge(headers)

    client.write("HTTP/1.1 #{status} #{reason}\r\n")
    response_headers.each { |name, value| client.write("#{name}: #{value}\r\n") }
    client.write("\r\n")
    client.write(body) unless head_only
  end
end
