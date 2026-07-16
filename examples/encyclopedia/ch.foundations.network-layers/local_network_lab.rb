# frozen_string_literal: true

require "json"
require "openssl"
require "socket"
require "timeout"

# Provides a loopback-only network stack that exposes DNS, TCP and TLS as
# separate observable stages. It never contacts the public network.
module LocalNetworkLab
  Result = Struct.new(:name, :ok, :failed_layer, :visited, :facts, keyword_init: true) do
    def to_h
      {
        name: name,
        ok: ok,
        failed_layer: failed_layer,
        visited: visited,
        facts: facts
      }
    end
  end

  module_function

  def certificate
    root_key = OpenSSL::PKey::RSA.new(2048)
    root = OpenSSL::X509::Certificate.new
    root.version = 2
    root.serial = 1
    root.subject = OpenSSL::X509::Name.parse("/CN=FactoryCare Ephemeral Lab Root")
    root.issuer = root.subject
    root.public_key = root_key.public_key
    root.not_before = Time.now - 60
    root.not_after = Time.now + 3600

    root_extensions = OpenSSL::X509::ExtensionFactory.new
    root_extensions.subject_certificate = root
    root_extensions.issuer_certificate = root
    root.add_extension(root_extensions.create_extension("basicConstraints", "CA:TRUE", true))
    root.add_extension(root_extensions.create_extension("keyUsage", "keyCertSign,cRLSign", true))
    root.add_extension(root_extensions.create_extension("subjectKeyIdentifier", "hash", false))
    root.sign(root_key, OpenSSL::Digest::SHA256.new)

    server_key = OpenSSL::PKey::RSA.new(2048)
    server = OpenSSL::X509::Certificate.new
    server.version = 2
    server.serial = 2
    server.subject = OpenSSL::X509::Name.parse("/CN=localhost")
    server.issuer = root.subject
    server.public_key = server_key.public_key
    server.not_before = Time.now - 60
    server.not_after = Time.now + 3600

    server_extensions = OpenSSL::X509::ExtensionFactory.new
    server_extensions.subject_certificate = server
    server_extensions.issuer_certificate = root
    server.add_extension(server_extensions.create_extension("basicConstraints", "CA:FALSE", true))
    server.add_extension(server_extensions.create_extension("keyUsage", "digitalSignature,keyEncipherment", true))
    server.add_extension(server_extensions.create_extension("extendedKeyUsage", "serverAuth", false))
    server.add_extension(server_extensions.create_extension("subjectAltName", "DNS:localhost", false))
    server.add_extension(server_extensions.create_extension("authorityKeyIdentifier", "keyid:always", false))
    server.sign(root_key, OpenSSL::Digest::SHA256.new)

    [server, server_key, root]
  end

  def start_tls_server(expected_connections:)
    cert, key, trust_anchor = certificate
    tcp_server = TCPServer.new("127.0.0.1", 0)
    context = OpenSSL::SSL::SSLContext.new
    context.cert = cert
    context.key = key
    ssl_server = OpenSSL::SSL::SSLServer.new(tcp_server, context)

    thread = Thread.new do
      expected_connections.times do
        socket = nil
        begin
          socket = ssl_server.accept
          socket.write("FACTORYCARE-TLS-OK\n")
        rescue OpenSSL::SSL::SSLError, IOError, SystemCallError
          # A failed client-side hostname check can close immediately after the
          # cryptographic handshake. That is an expected lab observation.
        ensure
          socket.close rescue nil
        end
      end
    end

    [tcp_server.addr[1], trust_anchor, thread, tcp_server]
  end

  def trusted_context(cert)
    store = OpenSSL::X509::Store.new
    store.add_cert(cert)
    context = OpenSSL::SSL::SSLContext.new
    context.verify_mode = OpenSSL::SSL::VERIFY_PEER
    context.cert_store = store
    context
  end

  def probe(name:, host:, port:, tls_hostname:, cert:)
    visited = []
    facts = {}
    socket = nil
    tls = nil

    visited << "dns"
    addresses = Addrinfo.getaddrinfo(host, nil, :INET, :STREAM).map(&:ip_address).uniq
    facts["dns_addresses"] = addresses

    visited << "tcp"
    socket = TCPSocket.new(addresses.first, port)
    facts["tcp_peer"] = "#{socket.peeraddr[3]}:#{socket.peeraddr[1]}"

    visited << "tls"
    tls = OpenSSL::SSL::SSLSocket.new(socket, trusted_context(cert))
    tls.sync_close = true
    tls.hostname = tls_hostname if tls.respond_to?(:hostname=)
    tls.connect
    tls.post_connection_check(tls_hostname)
    facts["tls_protocol"] = tls.ssl_version
    facts["certificate_subject"] = tls.peer_cert.subject.to_s
    facts["payload"] = tls.gets&.strip

    Result.new(name: name, ok: true, failed_layer: nil, visited: visited, facts: facts)
  rescue SocketError => error
    Result.new(name: name, ok: false, failed_layer: "dns", visited: visited,
               facts: facts.merge("error_class" => error.class.name, "error" => error.message))
  rescue Errno::ECONNREFUSED => error
    Result.new(name: name, ok: false, failed_layer: "tcp", visited: visited,
               facts: facts.merge("error_class" => error.class.name, "error" => error.message))
  rescue OpenSSL::SSL::SSLError => error
    Result.new(name: name, ok: false, failed_layer: "tls", visited: visited,
               facts: facts.merge("error_class" => error.class.name, "error" => error.message))
  ensure
    tls.close rescue nil
    socket.close rescue nil
  end

  def closed_loopback_port
    server = TCPServer.new("127.0.0.1", 0)
    port = server.addr[1]
    server.close
    port
  end

  def bounded_wait_timeout
    server = TCPServer.new("127.0.0.1", 0)
    accepted = Queue.new
    thread = Thread.new do
      socket = server.accept
      accepted << true
      sleep 0.4
      socket.close
    end

    client = TCPSocket.new("127.0.0.1", server.addr[1])
    accepted.pop
    readable = IO.select([client], nil, nil, 0.08)
    raise "expected a bounded wait timeout, but the socket became readable" if readable

    {
      "name" => "bounded-wait-timeout",
      "ok" => false,
      "failed_layer" => "tcp-wait",
      "timeout_seconds" => 0.08,
      "note" => "TCP connected; the bounded wait for bytes expired"
    }
  ensure
    client.close rescue nil
    server.close rescue nil
    thread.join(1) rescue nil
  end

  def run
    tls_port, cert, tls_thread, tcp_server = start_tls_server(expected_connections: 2)

    normal = probe(
      name: "normal-chain",
      host: "localhost",
      port: tls_port,
      tls_hostname: "localhost",
      cert: cert
    )

    bad_dns = probe(
      name: "invalid-hostname",
      host: "bad host name",
      port: tls_port,
      tls_hostname: "localhost",
      cert: cert
    )

    refused = probe(
      name: "closed-port",
      host: "localhost",
      port: closed_loopback_port,
      tls_hostname: "localhost",
      cert: cert
    )

    mismatch = probe(
      name: "certificate-name-mismatch",
      host: "localhost",
      port: tls_port,
      tls_hostname: "api.factorycare.invalid",
      cert: cert
    )

    {
      "normal" => normal.to_h,
      "failures" => [bad_dns.to_h, refused.to_h, mismatch.to_h],
      "timeout" => bounded_wait_timeout
    }
  ensure
    tcp_server.close rescue nil
    tls_thread.join(2) rescue nil
    tls_thread.kill if tls_thread&.alive?
  end
end

puts JSON.pretty_generate(LocalNetworkLab.run) if $PROGRAM_NAME == __FILE__
