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
import java.net.Socket;
import java.net.ServerSocket;
import java.net.SocketAddress;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.net.http.HttpTimeoutException;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.util.List;
import java.util.concurrent.CompletableFuture;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.ExecutionException;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.TimeoutException;

public final class NetworkProgrammingDemo {
    private static final int MAX_FRAME_BYTES = 1_024;
    private static final int CONNECT_TIMEOUT_MILLIS = 500;
    private static final int READ_TIMEOUT_MILLIS = 500;
    private static final Duration HTTP_TIMEOUT = Duration.ofMillis(600);
    private static int assertions;

    private NetworkProgrammingDemo() {
    }

    public static void main(String[] args) throws Exception {
        InetAddress loopback = InetAddress.getLoopbackAddress();
        SocketAddress unresolved = InetSocketAddress.createUnresolved("offline.invalid", 45_000);
        check(loopback.isLoopbackAddress(), "the fixture must use a loopback address");
        check(((InetSocketAddress) unresolved).isUnresolved(), "the offline fixture must remain unresolved");
        System.out.printf("address.loopback=%s unresolvedFixture=%s%n",
                loopback.isLoopbackAddress(), ((InetSocketAddress) unresolved).isUnresolved());

        TcpResult tcp = runTcpEcho(loopback);
        check(tcp.requestBytes() == 12, "TCP length must count UTF-8 bytes");
        check(tcp.responseBytes() == 16, "TCP response byte count must include the ASCII prefix");
        check(tcp.response().equals("ACK:维修单-42"), "TCP frame must round-trip exactly");
        check(tcp.clientClosed(), "TCP client must be closed");
        check(tcp.serverClosed(), "TCP server socket must be closed");
        check(tcp.executorTerminated(), "TCP executor must terminate");
        System.out.printf("tcp.requestBytes=%d responseBytes=%d response=%s%n",
                tcp.requestBytes(), tcp.responseBytes(), tcp.response());
        System.out.printf("tcp.closed=client:%s,server:%s,executor:%s%n",
                tcp.clientClosed(), tcp.serverClosed(), tcp.executorTerminated());

        UdpResult udp = runUdpEcho(loopback);
        check(udp.requestBytes() == 9, "UDP payload length must count UTF-8 bytes");
        check(udp.responseBytes() == 14, "UDP response must be one complete packet");
        check(udp.response().equals("ECHO:状态-OK"), "UDP payload must round-trip exactly");
        check(udp.receivedRequestLength() == udp.requestBytes(), "UDP receive must preserve packet length");
        check(udp.clientClosed(), "UDP client must be closed");
        check(udp.serverClosed(), "UDP server must be closed");
        check(udp.executorTerminated(), "UDP executor must terminate");
        System.out.printf("udp.requestPacketBytes=%d responsePacketBytes=%d response=%s%n",
                udp.requestBytes(), udp.responseBytes(), udp.response());
        System.out.printf("udp.closed=client:%s,server:%s,executor:%s%n",
                udp.clientClosed(), udp.serverClosed(), udp.executorTerminated());

        HttpResult http = runLocalHttp(loopback);
        check(http.okStatus() == 200, "HTTP success status must be inspected");
        check(http.okBody().equals("ready"), "HTTP success body must be decoded as UTF-8");
        check(http.unavailableStatus() == 503, "HTTP 503 must remain a response, not an exception");
        check(http.unavailableBody().equals("maintenance"), "HTTP error body must remain observable");
        check(http.classification().equals("retry-later"), "status handling must be explicit");
        check(http.timeoutType().equals("HttpTimeoutException"), "slow request must hit its request timeout");
        check(http.slowHandlerStarted(), "the slow request must reach the local handler");
        check(http.slowHandlerFinished(), "the slow handler must be released before cleanup");
        check(http.clientClosed(), "HttpClient try-with-resources scope must close");
        check(http.serverStopped(), "local HttpServer must stop");
        check(http.executorsTerminated(), "HTTP executors must terminate");
        System.out.printf("http.ok=%d:%s%n", http.okStatus(), http.okBody());
        System.out.printf("http.unavailable=%d:%s classification=%s%n",
                http.unavailableStatus(), http.unavailableBody(), http.classification());
        System.out.printf("http.timeout=%s handlerStarted=%s handlerFinished=%s%n",
                http.timeoutType(), http.slowHandlerStarted(), http.slowHandlerFinished());
        System.out.printf("http.closed=client:%s,server:%s,executors:%s%n",
                http.clientClosed(), http.serverStopped(), http.executorsTerminated());

        if (assertions != 26) {
            throw new AssertionError("assertion accounting drifted: " + assertions);
        }
        System.out.printf("assertions=%d passed%n", assertions);
    }

    private static TcpResult runTcpEcho(InetAddress loopback) throws Exception {
        ServerSocket server = new ServerSocket();
        ExecutorService executor = Executors.newSingleThreadExecutor();
        String request = "维修单-42";
        String response = null;
        boolean clientClosed = false;
        boolean executorTerminated;

        try {
            server.bind(new InetSocketAddress(loopback, 0));
            server.setSoTimeout(1_000);
            Future<String> serverTask = executor.submit(() -> {
                try (Socket peer = server.accept()) {
                    peer.setSoTimeout(READ_TIMEOUT_MILLIS);
                    try (DataInputStream input = new DataInputStream(peer.getInputStream());
                         DataOutputStream output = new DataOutputStream(peer.getOutputStream())) {
                        String received = readFrame(input);
                        writeFrame(output, "ACK:" + received);
                        return received;
                    }
                }
            });

            Socket client = new Socket();
            try (client) {
                client.connect(new InetSocketAddress(loopback, server.getLocalPort()), CONNECT_TIMEOUT_MILLIS);
                client.setSoTimeout(READ_TIMEOUT_MILLIS);
                try (DataOutputStream output = new DataOutputStream(client.getOutputStream());
                     DataInputStream input = new DataInputStream(client.getInputStream())) {
                    writeFrame(output, request);
                    response = readFrame(input);
                }
            }
            clientClosed = client.isClosed();
            String serverObserved = serverTask.get(2, TimeUnit.SECONDS);
            if (!serverObserved.equals(request)) {
                throw new AssertionError("server observed the wrong TCP frame");
            }
        } finally {
            server.close();
            executorTerminated = terminate(executor);
        }

        return new TcpResult(
                request.getBytes(StandardCharsets.UTF_8).length,
                response.getBytes(StandardCharsets.UTF_8).length,
                response,
                clientClosed,
                server.isClosed(),
                executorTerminated);
    }

    private static UdpResult runUdpEcho(InetAddress loopback) throws Exception {
        DatagramSocket server = new DatagramSocket(new InetSocketAddress(loopback, 0));
        DatagramSocket client = new DatagramSocket(new InetSocketAddress(loopback, 0));
        ExecutorService executor = Executors.newSingleThreadExecutor();
        String request = "状态-OK";
        String response = null;
        int receivedRequestLength = -1;
        boolean executorTerminated;

        server.setSoTimeout(READ_TIMEOUT_MILLIS);
        client.setSoTimeout(READ_TIMEOUT_MILLIS);
        try {
            Future<Integer> serverTask = executor.submit(() -> {
                byte[] receiveBuffer = new byte[64];
                DatagramPacket incoming = new DatagramPacket(receiveBuffer, receiveBuffer.length);
                server.receive(incoming);
                String received = new String(
                        incoming.getData(), incoming.getOffset(), incoming.getLength(), StandardCharsets.UTF_8);
                byte[] replyBytes = ("ECHO:" + received).getBytes(StandardCharsets.UTF_8);
                DatagramPacket reply = new DatagramPacket(replyBytes, replyBytes.length, incoming.getSocketAddress());
                server.send(reply);
                return incoming.getLength();
            });

            byte[] requestBytes = request.getBytes(StandardCharsets.UTF_8);
            client.send(new DatagramPacket(
                    requestBytes,
                    requestBytes.length,
                    new InetSocketAddress(loopback, server.getLocalPort())));
            byte[] responseBuffer = new byte[64];
            DatagramPacket responsePacket = new DatagramPacket(responseBuffer, responseBuffer.length);
            client.receive(responsePacket);
            response = new String(
                    responsePacket.getData(),
                    responsePacket.getOffset(),
                    responsePacket.getLength(),
                    StandardCharsets.UTF_8);
            receivedRequestLength = serverTask.get(2, TimeUnit.SECONDS);
        } finally {
            client.close();
            server.close();
            executorTerminated = terminate(executor);
        }

        return new UdpResult(
                request.getBytes(StandardCharsets.UTF_8).length,
                response.getBytes(StandardCharsets.UTF_8).length,
                response,
                receivedRequestLength,
                client.isClosed(),
                server.isClosed(),
                executorTerminated);
    }

    private static HttpResult runLocalHttp(InetAddress loopback) throws Exception {
        ExecutorService serverExecutor = Executors.newSingleThreadExecutor();
        ExecutorService clientExecutor = Executors.newFixedThreadPool(2);
        HttpServer server = HttpServer.create(new InetSocketAddress(loopback, 0), 0);
        CountDownLatch slowStarted = new CountDownLatch(1);
        CountDownLatch releaseSlow = new CountDownLatch(1);
        CountDownLatch slowFinished = new CountDownLatch(1);
        boolean clientClosed = false;
        boolean serverStopped = false;
        boolean executorsTerminated;
        int okStatus = -1;
        String okBody = null;
        int unavailableStatus = -1;
        String unavailableBody = null;
        String timeoutType = "none";
        boolean slowStartedObserved = false;
        boolean slowFinishedObserved = false;

        server.setExecutor(serverExecutor);
        server.createContext("/ok", exchange -> respond(exchange, 200, "ready"));
        server.createContext("/unavailable", exchange -> respond(exchange, 503, "maintenance"));
        server.createContext("/slow", exchange -> {
            slowStarted.countDown();
            try {
                releaseSlow.await(1, TimeUnit.SECONDS);
                respond(exchange, 200, "late");
            } catch (InterruptedException interrupted) {
                Thread.currentThread().interrupt();
                exchange.close();
            } catch (IOException ignoredAfterClientTimeout) {
                exchange.close();
            } finally {
                slowFinished.countDown();
            }
        });
        server.start();

        try {
            URI okUri = localUri(loopback, server.getAddress().getPort(), "/ok");
            URI unavailableUri = localUri(loopback, server.getAddress().getPort(), "/unavailable");
            URI slowUri = localUri(loopback, server.getAddress().getPort(), "/slow");
            try (HttpClient client = HttpClient.newBuilder()
                    .connectTimeout(Duration.ofMillis(CONNECT_TIMEOUT_MILLIS))
                    .executor(clientExecutor)
                    .proxy(new DirectProxySelector())
                    .version(HttpClient.Version.HTTP_1_1)
                    .followRedirects(HttpClient.Redirect.NEVER)
                    .build()) {
                HttpResponse<String> ok = client.send(
                        request(okUri, HTTP_TIMEOUT),
                        HttpResponse.BodyHandlers.ofString(StandardCharsets.UTF_8));
                okStatus = ok.statusCode();
                okBody = ok.body();

                HttpResponse<String> unavailable = client.send(
                        request(unavailableUri, HTTP_TIMEOUT),
                        HttpResponse.BodyHandlers.ofString(StandardCharsets.UTF_8));
                unavailableStatus = unavailable.statusCode();
                unavailableBody = unavailable.body();

                CompletableFuture<HttpResponse<String>> pending = client.sendAsync(
                        request(slowUri, Duration.ofMillis(300)),
                        HttpResponse.BodyHandlers.ofString(StandardCharsets.UTF_8));
                slowStartedObserved = slowStarted.await(1, TimeUnit.SECONDS);
                try {
                    pending.get(2, TimeUnit.SECONDS);
                    throw new AssertionError("slow local request should time out");
                } catch (ExecutionException expected) {
                    Throwable cause = expected.getCause();
                    if (!(cause instanceof HttpTimeoutException)) {
                        throw expected;
                    }
                    timeoutType = cause.getClass().getSimpleName();
                } catch (TimeoutException harnessTimeout) {
                    pending.cancel(true);
                    throw new AssertionError("HttpClient request timeout did not fire", harnessTimeout);
                } finally {
                    releaseSlow.countDown();
                }
                slowFinishedObserved = slowFinished.await(1, TimeUnit.SECONDS);
            }
            clientClosed = true;
        } finally {
            releaseSlow.countDown();
            server.stop(0);
            serverStopped = true;
            boolean serverExecutorTerminated = terminate(serverExecutor);
            boolean clientExecutorTerminated = terminate(clientExecutor);
            executorsTerminated = serverExecutorTerminated && clientExecutorTerminated;
        }

        return new HttpResult(
                okStatus,
                okBody,
                unavailableStatus,
                unavailableBody,
                classifyStatus(unavailableStatus),
                timeoutType,
                slowStartedObserved,
                slowFinishedObserved,
                clientClosed,
                serverStopped,
                executorsTerminated);
    }

    private static HttpRequest request(URI uri, Duration timeout) {
        return HttpRequest.newBuilder(uri)
                .timeout(timeout)
                .header("Accept", "text/plain; charset=utf-8")
                .GET()
                .build();
    }

    private static URI localUri(InetAddress loopback, int port, String path) throws Exception {
        return new URI("http", null, loopback.getHostAddress(), port, path, null, null);
    }

    private static String classifyStatus(int status) {
        return status == 503 ? "retry-later" : "unexpected";
    }

    private static void respond(HttpExchange exchange, int status, String text) throws IOException {
        byte[] body = text.getBytes(StandardCharsets.UTF_8);
        exchange.getResponseHeaders().set("Content-Type", "text/plain; charset=utf-8");
        exchange.sendResponseHeaders(status, body.length);
        try (OutputStream output = exchange.getResponseBody()) {
            output.write(body);
        } finally {
            exchange.close();
        }
    }

    private static void writeFrame(DataOutputStream output, String text) throws IOException {
        byte[] bytes = text.getBytes(StandardCharsets.UTF_8);
        if (bytes.length > MAX_FRAME_BYTES) {
            throw new IOException("frame exceeds " + MAX_FRAME_BYTES + " bytes");
        }
        output.writeInt(bytes.length);
        output.write(bytes);
        output.flush();
    }

    private static String readFrame(DataInputStream input) throws IOException {
        int length = input.readInt();
        if (length < 0 || length > MAX_FRAME_BYTES) {
            throw new IOException("invalid frame length: " + length);
        }
        byte[] bytes = new byte[length];
        input.readFully(bytes);
        return new String(bytes, StandardCharsets.UTF_8);
    }

    private static boolean terminate(ExecutorService executor) throws InterruptedException {
        executor.shutdown();
        if (!executor.awaitTermination(1, TimeUnit.SECONDS)) {
            executor.shutdownNow();
            if (!executor.awaitTermination(1, TimeUnit.SECONDS)) {
                throw new AssertionError("executor did not terminate");
            }
        }
        return executor.isTerminated();
    }

    private static final class DirectProxySelector extends ProxySelector {
        @Override
        public List<Proxy> select(URI uri) {
            return List.of(Proxy.NO_PROXY);
        }

        @Override
        public void connectFailed(URI uri, SocketAddress address, IOException failure) {
            throw new AssertionError("a direct loopback request must not report a proxy failure", failure);
        }
    }

    private static void check(boolean condition, String message) {
        if (!condition) {
            throw new AssertionError(message);
        }
        assertions++;
    }

    private record TcpResult(
            int requestBytes,
            int responseBytes,
            String response,
            boolean clientClosed,
            boolean serverClosed,
            boolean executorTerminated) {
    }

    private record UdpResult(
            int requestBytes,
            int responseBytes,
            String response,
            int receivedRequestLength,
            boolean clientClosed,
            boolean serverClosed,
            boolean executorTerminated) {
    }

    private record HttpResult(
            int okStatus,
            String okBody,
            int unavailableStatus,
            String unavailableBody,
            String classification,
            String timeoutType,
            boolean slowHandlerStarted,
            boolean slowHandlerFinished,
            boolean clientClosed,
            boolean serverStopped,
            boolean executorsTerminated) {
    }
}
