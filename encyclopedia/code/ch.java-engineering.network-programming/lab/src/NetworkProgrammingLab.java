import com.sun.net.httpserver.HttpExchange;
import com.sun.net.httpserver.HttpServer;

import java.io.ByteArrayInputStream;
import java.io.ByteArrayOutputStream;
import java.io.DataInputStream;
import java.io.DataOutputStream;
import java.io.EOFException;
import java.io.IOException;
import java.io.InputStream;
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
import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.CompletableFuture;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.ExecutionException;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.TimeoutException;

public final class NetworkProgrammingLab {
    private static final int HEADER_BYTES = Integer.BYTES;
    private static final int MAX_FRAME_BYTES = 1_024;
    private static final int CONNECT_TIMEOUT_MILLIS = 500;
    private static final int READ_TIMEOUT_MILLIS = 500;
    private static final Duration HTTP_TIMEOUT = Duration.ofMillis(700);
    private static int assertions;

    private NetworkProgrammingLab() {
    }

    public static void main(String[] args) throws Exception {
        InetAddress loopback = InetAddress.getLoopbackAddress();
        InetSocketAddress unresolved = InetSocketAddress.createUnresolved("offline.invalid", 45_000);
        check(loopback.isLoopbackAddress(), "fixture address must be loopback");
        check(unresolved.isUnresolved(), "offline authority must remain unresolved");
        System.out.printf("address.loopback=%s unresolvedFixture=%s%n",
                loopback.isLoopbackAddress(), unresolved.isUnresolved());

        FrameEvidence frame = inspectFrames();
        check(frame.emptyPayloadBytes() == 0, "empty payload length must be zero");
        check(frame.utf8PayloadBytes() == 12, "frame length must use UTF-8 bytes");
        check(frame.headerBytes() == 4, "frame header must be one big-endian int");
        check(frame.decoded().equals("维修单-84"), "UTF-8 frame must round-trip");
        check(frame.readFullyRecovered(), "readFully must recover from repeated short reads");
        check(frame.truncatedType().equals("EOFException"), "truncated frame must fail closed");
        check(frame.oversizedType().equals("FrameTooLargeException"), "oversized frame must fail before allocation");
        check(frame.maximumBytes() == MAX_FRAME_BYTES, "reported frame maximum must match enforcement");
        System.out.printf("frame.emptyPayloadBytes=%d utf8PayloadBytes=%d headerBytes=%d%n",
                frame.emptyPayloadBytes(), frame.utf8PayloadBytes(), frame.headerBytes());
        System.out.printf("frame.readFullyRecovered=%s truncated=%s oversized=%s max=%d%n",
                frame.readFullyRecovered(), frame.truncatedType(), frame.oversizedType(), frame.maximumBytes());

        TcpResult tcp = runTcpEcho(loopback);
        check(tcp.requestBytes() == 12, "TCP request must use UTF-8 byte count");
        check(tcp.responseBytes() == 16, "TCP response byte count must include prefix");
        check(tcp.response().equals("ACK:维修单-84"), "TCP response must preserve one frame");
        check(tcp.serverObserved().equals("维修单-84"), "server must decode the original frame");
        check(tcp.clientClosed(), "TCP client must close");
        check(tcp.serverClosed(), "TCP listener must close");
        check(tcp.executorTerminated(), "TCP worker must terminate");
        System.out.printf("tcp.requestBytes=%d responseBytes=%d response=%s%n",
                tcp.requestBytes(), tcp.responseBytes(), tcp.response());
        System.out.printf("tcp.closed=client:%s,server:%s,executor:%s%n",
                tcp.clientClosed(), tcp.serverClosed(), tcp.executorTerminated());

        UdpResult udp = runUdpBoundaries(loopback);
        check(udp.requestLengths().equals(List.of(1, 6)), "UDP receive must preserve both request packet lengths");
        check(udp.requestLengths().get(1) == 6, "second UDP packet must remain six bytes");
        check(udp.responseLengths().get(0) == 3, "first UDP reply must remain one packet");
        check(udp.responseLengths().get(1) == 8, "second UDP reply must remain one packet");
        check(udp.responses().equals(List.of("1:A", "2:状态")), "UDP responses must not merge");
        check(udp.boundaryCount() == 2, "two sends must require two receives");
        check(udp.clientClosed(), "UDP client must close");
        check(udp.serverClosed(), "UDP server must close");
        check(udp.executorTerminated(), "UDP worker must terminate");
        System.out.printf("udp.packetLengths=%d,%d responseBytes=%d,%d responses=%s|%s%n",
                udp.requestLengths().get(0), udp.requestLengths().get(1),
                udp.responseLengths().get(0), udp.responseLengths().get(1),
                udp.responses().get(0), udp.responses().get(1));
        System.out.printf("udp.boundaryCount=%d closed=client:%s,server:%s,executor:%s%n",
                udp.boundaryCount(), udp.clientClosed(), udp.serverClosed(), udp.executorTerminated());

        HttpResult http = runLocalHttp(loopback);
        check(http.uriScheme().equals("http"), "local URI scheme must be explicit");
        check(http.uriPath().equals("/ok"), "local URI path must be explicit");
        check(http.dynamicPort(), "local HTTP server must use a system-assigned port");
        check(http.okStatus() == 200, "HTTP 200 must be inspected");
        check(http.okBody().equals("ready"), "HTTP 200 body must be decoded as UTF-8");
        check(http.unavailableStatus() == 503, "HTTP 503 must remain a response");
        check(http.unavailableBody().equals("maintenance"), "HTTP 503 body must remain observable");
        check(http.action().equals("surface-maintenance"), "status-to-action mapping must be explicit");
        check(http.timeoutType().equals("HttpTimeoutException"), "slow request must hit request timeout");
        check(http.slowHandlerStarted(), "slow request must reach local server");
        check(http.slowHandlerFinished(), "slow handler must finish before cleanup");
        check(http.clientClosed(), "HttpClient owner must close its scope");
        check(http.serverStopped(), "HttpServer owner must stop it");
        check(http.executorsTerminated(), "HTTP executors must terminate");
        System.out.printf("uri.scheme=%s path=%s dynamicPort=%s%n",
                http.uriScheme(), http.uriPath(), http.dynamicPort());
        System.out.printf("http.ok=%d:%s%n", http.okStatus(), http.okBody());
        System.out.printf("http.unavailable=%d:%s action=%s%n",
                http.unavailableStatus(), http.unavailableBody(), http.action());
        System.out.printf("http.timeout=%s handlerStarted=%s handlerFinished=%s%n",
                http.timeoutType(), http.slowHandlerStarted(), http.slowHandlerFinished());
        System.out.printf("http.closed=client:%s,server:%s,executors:%s%n",
                http.clientClosed(), http.serverStopped(), http.executorsTerminated());

        if (assertions != 40) {
            throw new AssertionError("assertion accounting drifted: " + assertions);
        }
        System.out.printf("assertions=%d passed%n", assertions);
    }

    private static FrameEvidence inspectFrames() throws IOException {
        byte[] empty = encodeFrame("");
        String text = "维修单-84";
        byte[] encoded = encodeFrame(text);
        ShortReadInputStream shortReads = new ShortReadInputStream(encoded, 2);
        String decoded;
        try (DataInputStream input = new DataInputStream(shortReads)) {
            decoded = readFrame(input);
        }

        String truncatedType = "none";
        try (DataInputStream input = new DataInputStream(new ByteArrayInputStream(truncatedFrame()))) {
            readFrame(input);
        } catch (EOFException expected) {
            truncatedType = expected.getClass().getSimpleName();
        }

        String oversizedType = "none";
        try (DataInputStream input = new DataInputStream(new ByteArrayInputStream(lengthOnly(MAX_FRAME_BYTES + 1)))) {
            readFrame(input);
        } catch (FrameTooLargeException expected) {
            oversizedType = expected.getClass().getSimpleName();
        }

        return new FrameEvidence(
                empty.length - HEADER_BYTES,
                text.getBytes(StandardCharsets.UTF_8).length,
                HEADER_BYTES,
                decoded,
                decoded.equals(text) && shortReads.bulkReadCalls() > 1,
                truncatedType,
                oversizedType,
                MAX_FRAME_BYTES);
    }

    private static TcpResult runTcpEcho(InetAddress loopback) throws Exception {
        ServerSocket server = new ServerSocket();
        ExecutorService executor = Executors.newSingleThreadExecutor();
        String request = "维修单-84";
        String response = null;
        String serverObserved = null;
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
            serverObserved = serverTask.get(2, TimeUnit.SECONDS);
        } finally {
            server.close();
            executorTerminated = terminate(executor);
        }

        return new TcpResult(
                request.getBytes(StandardCharsets.UTF_8).length,
                response.getBytes(StandardCharsets.UTF_8).length,
                response,
                serverObserved,
                clientClosed,
                server.isClosed(),
                executorTerminated);
    }

    private static UdpResult runUdpBoundaries(InetAddress loopback) throws Exception {
        DatagramSocket server = new DatagramSocket(new InetSocketAddress(loopback, 0));
        DatagramSocket client = new DatagramSocket(new InetSocketAddress(loopback, 0));
        ExecutorService executor = Executors.newSingleThreadExecutor();
        List<String> requests = List.of("A", "状态");
        List<String> responses = new ArrayList<>();
        List<Integer> responseLengths = new ArrayList<>();
        List<Integer> requestLengths = List.of();
        boolean executorTerminated;

        server.setSoTimeout(READ_TIMEOUT_MILLIS);
        client.setSoTimeout(READ_TIMEOUT_MILLIS);
        try {
            Future<List<Integer>> serverTask = executor.submit(() -> {
                List<Integer> observedLengths = new ArrayList<>();
                for (int index = 0; index < requests.size(); index++) {
                    byte[] receiveBuffer = new byte[64];
                    DatagramPacket incoming = new DatagramPacket(receiveBuffer, receiveBuffer.length);
                    server.receive(incoming);
                    observedLengths.add(incoming.getLength());
                    String received = new String(
                            incoming.getData(), incoming.getOffset(), incoming.getLength(), StandardCharsets.UTF_8);
                    byte[] replyBytes = ((index + 1) + ":" + received).getBytes(StandardCharsets.UTF_8);
                    server.send(new DatagramPacket(replyBytes, replyBytes.length, incoming.getSocketAddress()));
                }
                return List.copyOf(observedLengths);
            });

            for (String request : requests) {
                byte[] requestBytes = request.getBytes(StandardCharsets.UTF_8);
                client.send(new DatagramPacket(
                        requestBytes,
                        requestBytes.length,
                        new InetSocketAddress(loopback, server.getLocalPort())));
                byte[] responseBuffer = new byte[64];
                DatagramPacket responsePacket = new DatagramPacket(responseBuffer, responseBuffer.length);
                client.receive(responsePacket);
                responses.add(new String(
                        responsePacket.getData(),
                        responsePacket.getOffset(),
                        responsePacket.getLength(),
                        StandardCharsets.UTF_8));
                responseLengths.add(responsePacket.getLength());
            }
            requestLengths = serverTask.get(2, TimeUnit.SECONDS);
        } finally {
            client.close();
            server.close();
            executorTerminated = terminate(executor);
        }

        return new UdpResult(
                List.copyOf(requestLengths),
                List.copyOf(responseLengths),
                List.copyOf(responses),
                responses.size(),
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
        String uriScheme = null;
        String uriPath = null;
        boolean dynamicPort = false;
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
            int port = server.getAddress().getPort();
            URI okUri = localUri(loopback, port, "/ok");
            URI unavailableUri = localUri(loopback, port, "/unavailable");
            URI slowUri = localUri(loopback, port, "/slow");
            uriScheme = okUri.getScheme();
            uriPath = okUri.getPath();
            dynamicPort = port > 0;

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
                        request(slowUri, Duration.ofMillis(350)),
                        HttpResponse.BodyHandlers.ofString(StandardCharsets.UTF_8));
                slowStartedObserved = slowStarted.await(1, TimeUnit.SECONDS);
                try {
                    pending.get(2, TimeUnit.SECONDS);
                    throw new AssertionError("slow local HTTP request should time out");
                } catch (ExecutionException expected) {
                    Throwable cause = expected.getCause();
                    if (!(cause instanceof HttpTimeoutException)) {
                        throw expected;
                    }
                    timeoutType = cause.getClass().getSimpleName();
                } catch (TimeoutException harnessTimeout) {
                    pending.cancel(true);
                    throw new AssertionError("HttpClient timeout did not fire", harnessTimeout);
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
                uriScheme,
                uriPath,
                dynamicPort,
                okStatus,
                okBody,
                unavailableStatus,
                unavailableBody,
                unavailableStatus == 503 ? "surface-maintenance" : "unexpected",
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

    private static byte[] encodeFrame(String text) throws IOException {
        ByteArrayOutputStream bytes = new ByteArrayOutputStream();
        try (DataOutputStream output = new DataOutputStream(bytes)) {
            writeFrame(output, text);
        }
        return bytes.toByteArray();
    }

    private static byte[] truncatedFrame() throws IOException {
        ByteArrayOutputStream bytes = new ByteArrayOutputStream();
        try (DataOutputStream output = new DataOutputStream(bytes)) {
            output.writeInt(4);
            output.write(new byte[]{'O', 'K'});
        }
        return bytes.toByteArray();
    }

    private static byte[] lengthOnly(int length) throws IOException {
        ByteArrayOutputStream bytes = new ByteArrayOutputStream();
        try (DataOutputStream output = new DataOutputStream(bytes)) {
            output.writeInt(length);
        }
        return bytes.toByteArray();
    }

    private static void writeFrame(DataOutputStream output, String text) throws IOException {
        byte[] bytes = text.getBytes(StandardCharsets.UTF_8);
        if (bytes.length > MAX_FRAME_BYTES) {
            throw new FrameTooLargeException(bytes.length, MAX_FRAME_BYTES);
        }
        output.writeInt(bytes.length);
        output.write(bytes);
        output.flush();
    }

    private static String readFrame(DataInputStream input) throws IOException {
        int length = input.readInt();
        if (length < 0 || length > MAX_FRAME_BYTES) {
            throw new FrameTooLargeException(length, MAX_FRAME_BYTES);
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

    private static final class FrameTooLargeException extends IOException {
        private FrameTooLargeException(int declared, int maximum) {
            super("declared=" + declared + ", maximum=" + maximum);
        }
    }

    private static final class ShortReadInputStream extends InputStream {
        private final byte[] bytes;
        private final int maximumChunk;
        private int position;
        private int bulkReadCalls;

        private ShortReadInputStream(byte[] bytes, int maximumChunk) {
            this.bytes = bytes.clone();
            this.maximumChunk = maximumChunk;
        }

        @Override
        public int read() {
            return position < bytes.length ? bytes[position++] & 0xff : -1;
        }

        @Override
        public int read(byte[] destination, int offset, int length) {
            if (position >= bytes.length) {
                return -1;
            }
            bulkReadCalls++;
            int count = Math.min(Math.min(length, maximumChunk), bytes.length - position);
            System.arraycopy(bytes, position, destination, offset, count);
            position += count;
            return count;
        }

        private int bulkReadCalls() {
            return bulkReadCalls;
        }
    }

    private record FrameEvidence(
            int emptyPayloadBytes,
            int utf8PayloadBytes,
            int headerBytes,
            String decoded,
            boolean readFullyRecovered,
            String truncatedType,
            String oversizedType,
            int maximumBytes) {
    }

    private record TcpResult(
            int requestBytes,
            int responseBytes,
            String response,
            String serverObserved,
            boolean clientClosed,
            boolean serverClosed,
            boolean executorTerminated) {
    }

    private record UdpResult(
            List<Integer> requestLengths,
            List<Integer> responseLengths,
            List<String> responses,
            int boundaryCount,
            boolean clientClosed,
            boolean serverClosed,
            boolean executorTerminated) {
    }

    private record HttpResult(
            String uriScheme,
            String uriPath,
            boolean dynamicPort,
            int okStatus,
            String okBody,
            int unavailableStatus,
            String unavailableBody,
            String action,
            String timeoutType,
            boolean slowHandlerStarted,
            boolean slowHandlerFinished,
            boolean clientClosed,
            boolean serverStopped,
            boolean executorsTerminated) {
    }
}
