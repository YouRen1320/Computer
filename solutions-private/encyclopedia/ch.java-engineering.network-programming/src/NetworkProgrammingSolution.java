import com.sun.net.httpserver.HttpExchange;
import com.sun.net.httpserver.HttpServer;
import java.io.DataInputStream;
import java.io.DataOutputStream;
import java.io.IOException;
import java.io.OutputStream;
import java.net.DatagramPacket;
import java.net.DatagramSocket;
import java.net.InetAddress;
import java.net.InetSocketAddress;
import java.net.Proxy;
import java.net.ProxySelector;
import java.net.ServerSocket;
import java.net.Socket;
import java.net.SocketAddress;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.net.http.HttpTimeoutException;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.util.List;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;
import java.util.concurrent.TimeUnit;

public final class NetworkProgrammingSolution {
    private static final int MAX_FRAME_BYTES = 2_048;

    private NetworkProgrammingSolution() {
    }

    record TcpObservation(String text, int frameBytes, boolean clientClosed, boolean listenerClosed) {
    }

    record UdpObservation(String text, int datagramBytes, boolean senderClosed, boolean receiverClosed) {
    }

    record HttpObservation(URI uri, int okStatus, String okBody, int unavailableStatus, boolean timedOut) {
    }

    public static void main(String[] args) throws Exception {
        InetAddress loopback = InetAddress.getLoopbackAddress();
        TcpObservation tcp = runTcpEcho(loopback, "设备-A17");
        UdpObservation udp = runUdpEcho(loopback, "alarm=A17");
        HttpObservation http = runLocalHttp(loopback);

        int assertions = 0;
        assertions = check(loopback.isLoopbackAddress(), "loopback", assertions);
        assertions = check("设备-A17".equals(tcp.text()), "TCP text", assertions);
        assertions = check(tcp.frameBytes() == "设备-A17".getBytes(StandardCharsets.UTF_8).length,
                "TCP byte length", assertions);
        assertions = check(tcp.frameBytes() > "设备-A17".length(), "multibyte fixture", assertions);
        assertions = check(tcp.clientClosed(), "TCP client closed", assertions);
        assertions = check(tcp.listenerClosed(), "TCP listener closed", assertions);
        assertions = check("alarm=A17".equals(udp.text()), "UDP text", assertions);
        assertions = check(udp.datagramBytes() == 9, "UDP packet length", assertions);
        assertions = check(udp.senderClosed(), "UDP sender closed", assertions);
        assertions = check(udp.receiverClosed(), "UDP receiver closed", assertions);
        assertions = check("http".equals(http.uri().getScheme()), "URI scheme", assertions);
        assertions = check(http.uri().getPort() > 0, "ephemeral HTTP port", assertions);
        assertions = check("/health".equals(http.uri().getPath()), "URI path", assertions);
        assertions = check(http.uri().getUserInfo() == null, "no URI credentials", assertions);
        assertions = check(http.okStatus() == 200, "HTTP success status", assertions);
        assertions = check("ready".equals(http.okBody()), "HTTP UTF-8 body", assertions);
        assertions = check(http.unavailableStatus() == 503, "HTTP non-2xx preserved", assertions);
        assertions = check(http.timedOut(), "HTTP request timeout", assertions);
        assertions = check(tcp.frameBytes() <= MAX_FRAME_BYTES, "frame bound", assertions);
        assertions = check(http.uri().getHost() != null, "structured URI host", assertions);

        System.out.println("solution.tcpUtf8=" + "设备-A17".equals(tcp.text()));
        System.out.println("solution.tcpFrameBytes=" + tcp.frameBytes());
        System.out.println("solution.tcpClosed=" + (tcp.clientClosed() && tcp.listenerClosed()));
        System.out.println("solution.udp=" + udp.text());
        System.out.println("solution.udpDatagramBytes=" + udp.datagramBytes());
        System.out.println("solution.udpClosed=" + (udp.senderClosed() && udp.receiverClosed()));
        System.out.println("solution.httpStatus=" + http.okStatus());
        System.out.println("solution.httpBody=" + http.okBody());
        System.out.println("solution.httpUnavailable=" + http.unavailableStatus());
        System.out.println("solution.httpTimedOut=" + http.timedOut());
        System.out.println("solution.assertions=" + assertions + " passed");
    }

    private static TcpObservation runTcpEcho(InetAddress loopback, String text) throws Exception {
        byte[] payload = text.getBytes(StandardCharsets.UTF_8);
        ServerSocket listener = new ServerSocket();
        Socket client = new Socket();
        String echoedText;
        int echoedBytes;
        try (listener) {
            listener.bind(new InetSocketAddress(loopback, 0));
            listener.setSoTimeout(1_000);
            try (ExecutorService executor = Executors.newSingleThreadExecutor()) {
                Future<Integer> server = executor.submit(() -> {
                    try (Socket peer = listener.accept()) {
                        peer.setSoTimeout(500);
                        byte[] request = readFrame(new DataInputStream(peer.getInputStream()));
                        writeFrame(new DataOutputStream(peer.getOutputStream()), request);
                        return request.length;
                    }
                });
                try (client) {
                    client.connect(new InetSocketAddress(loopback, listener.getLocalPort()), 500);
                    client.setSoTimeout(500);
                    writeFrame(new DataOutputStream(client.getOutputStream()), payload);
                    byte[] echoed = readFrame(new DataInputStream(client.getInputStream()));
                    echoedText = new String(echoed, StandardCharsets.UTF_8);
                    echoedBytes = echoed.length;
                }
                if (server.get(1, TimeUnit.SECONDS) != payload.length) {
                    throw new AssertionError("server frame length");
                }
            }
        }
        return new TcpObservation(echoedText, echoedBytes, client.isClosed(), listener.isClosed());
    }

    private static byte[] readFrame(DataInputStream input) throws IOException {
        int length = input.readInt();
        if (length < 0 || length > MAX_FRAME_BYTES) {
            throw new IOException("invalid frame length=" + length);
        }
        byte[] payload = new byte[length];
        input.readFully(payload);
        return payload;
    }

    private static void writeFrame(DataOutputStream output, byte[] payload) throws IOException {
        if (payload.length > MAX_FRAME_BYTES) {
            throw new IOException("frame too large=" + payload.length);
        }
        output.writeInt(payload.length);
        output.write(payload);
        output.flush();
    }

    private static UdpObservation runUdpEcho(InetAddress loopback, String text) throws Exception {
        byte[] payload = text.getBytes(StandardCharsets.UTF_8);
        DatagramSocket receiver = new DatagramSocket(new InetSocketAddress(loopback, 0));
        DatagramSocket sender = new DatagramSocket(new InetSocketAddress(loopback, 0));
        String echoedText;
        int echoedLength;
        try (receiver; sender; ExecutorService executor = Executors.newSingleThreadExecutor()) {
            receiver.setSoTimeout(500);
            sender.setSoTimeout(500);
            Future<Integer> echo = executor.submit(() -> {
                byte[] buffer = new byte[128];
                DatagramPacket request = new DatagramPacket(buffer, buffer.length);
                receiver.receive(request);
                DatagramPacket response = new DatagramPacket(
                        request.getData(), request.getLength(), request.getSocketAddress());
                receiver.send(response);
                return request.getLength();
            });

            sender.connect(new InetSocketAddress(loopback, receiver.getLocalPort()));
            sender.send(new DatagramPacket(payload, payload.length));
            byte[] responseBuffer = new byte[128];
            DatagramPacket response = new DatagramPacket(responseBuffer, responseBuffer.length);
            sender.receive(response);
            echoedLength = response.getLength();
            echoedText = new String(response.getData(), response.getOffset(), response.getLength(),
                    StandardCharsets.UTF_8);
            if (echo.get(1, TimeUnit.SECONDS) != payload.length) {
                throw new AssertionError("UDP packet length");
            }
        }
        return new UdpObservation(echoedText, echoedLength, sender.isClosed(), receiver.isClosed());
    }

    private static HttpObservation runLocalHttp(InetAddress loopback) throws Exception {
        HttpServer server = HttpServer.create(new InetSocketAddress(loopback, 0), 0);
        ExecutorService serverExecutor = Executors.newFixedThreadPool(2);
        server.setExecutor(serverExecutor);
        server.createContext("/health", exchange -> respond(exchange, 200, "ready"));
        server.createContext("/unavailable", exchange -> respond(exchange, 503, "busy"));
        server.createContext("/slow", exchange -> {
            try {
                Thread.sleep(300);
                respond(exchange, 200, "late");
            } catch (InterruptedException interrupted) {
                Thread.currentThread().interrupt();
                exchange.close();
            } catch (IOException clientClosed) {
                exchange.close();
            }
        });
        server.start();

        URI healthUri = localUri(loopback, server.getAddress().getPort(), "/health");
        URI unavailableUri = localUri(loopback, server.getAddress().getPort(), "/unavailable");
        URI slowUri = localUri(loopback, server.getAddress().getPort(), "/slow");
        int okStatus;
        String okBody;
        int unavailableStatus;
        boolean timedOut = false;
        try (HttpClient client = HttpClient.newBuilder()
                .connectTimeout(Duration.ofMillis(500))
                .proxy(new DirectProxySelector())
                .version(HttpClient.Version.HTTP_1_1)
                .followRedirects(HttpClient.Redirect.NEVER)
                .build()) {
            HttpRequest healthRequest = HttpRequest.newBuilder(healthUri)
                    .timeout(Duration.ofSeconds(1))
                    .GET()
                    .build();
            HttpResponse<String> health = client.send(
                    healthRequest, HttpResponse.BodyHandlers.ofString(StandardCharsets.UTF_8));
            okStatus = health.statusCode();
            okBody = health.body();

            HttpRequest unavailableRequest = HttpRequest.newBuilder(unavailableUri)
                    .timeout(Duration.ofSeconds(1))
                    .GET()
                    .build();
            unavailableStatus = client.send(
                    unavailableRequest, HttpResponse.BodyHandlers.discarding()).statusCode();

            HttpRequest slowRequest = HttpRequest.newBuilder(slowUri)
                    .timeout(Duration.ofMillis(80))
                    .GET()
                    .build();
            try {
                client.send(slowRequest, HttpResponse.BodyHandlers.discarding());
            } catch (HttpTimeoutException expected) {
                timedOut = true;
            }
        } finally {
            server.stop(0);
            serverExecutor.shutdownNow();
            if (!serverExecutor.awaitTermination(1, TimeUnit.SECONDS)) {
                throw new AssertionError("HTTP executor did not terminate");
            }
        }
        return new HttpObservation(healthUri, okStatus, okBody, unavailableStatus, timedOut);
    }

    private static URI localUri(InetAddress loopback, int port, String path) throws Exception {
        return new URI("http", null, loopback.getHostAddress(), port, path, null, null);
    }

    private static void respond(HttpExchange exchange, int status, String body) throws IOException {
        byte[] payload = body.getBytes(StandardCharsets.UTF_8);
        try (exchange) {
            exchange.getResponseHeaders().set("Content-Type", "text/plain; charset=utf-8");
            exchange.sendResponseHeaders(status, payload.length);
            try (OutputStream output = exchange.getResponseBody()) {
                output.write(payload);
            }
        }
    }

    private static int check(boolean condition, String message, int assertions) {
        if (!condition) {
            throw new AssertionError(message);
        }
        return assertions + 1;
    }

    private static final class DirectProxySelector extends ProxySelector {
        @Override
        public List<Proxy> select(URI uri) {
            return List.of(Proxy.NO_PROXY);
        }

        @Override
        public void connectFailed(URI uri, SocketAddress address, IOException failure) {
            throw new AssertionError("direct connection should not report a proxy failure", failure);
        }
    }
}
