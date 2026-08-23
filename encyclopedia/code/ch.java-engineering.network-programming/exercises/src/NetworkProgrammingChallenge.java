import java.io.DataInputStream;
import java.io.DataOutputStream;
import java.net.InetAddress;
import java.net.InetSocketAddress;
import java.net.ServerSocket;
import java.net.Socket;
import java.nio.charset.StandardCharsets;
import java.util.Arrays;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;
import java.util.concurrent.TimeUnit;

public final class NetworkProgrammingChallenge {
    private static final int MAX_FRAME_BYTES = 1_024;

    private NetworkProgrammingChallenge() {
    }

    public static void main(String[] args) throws Exception {
        InetAddress loopback = InetAddress.getLoopbackAddress();
        String message = "设备-A17";
        byte[] payload = message.getBytes(StandardCharsets.UTF_8);

        int declaredLength = message.length(); // TODO: frame length is the encoded UTF-8 byte count.
        byte[] echoed;
        int serverLength;
        boolean clientClosed;
        boolean listenerClosed;

        ServerSocket listener = new ServerSocket();
        try {
            listener.bind(new InetSocketAddress(loopback, 0));
            listener.setSoTimeout(1_000);
            try (ExecutorService executor = Executors.newSingleThreadExecutor()) {
                Future<Integer> server = executor.submit(() -> echoOneFrame(listener));
                Socket client = new Socket();
                try (client) {
                    client.connect(new InetSocketAddress(loopback, listener.getLocalPort()), 500);
                    client.setSoTimeout(500);
                    DataOutputStream output = new DataOutputStream(client.getOutputStream());
                    output.writeInt(declaredLength);
                    output.write(payload);
                    output.flush();

                    DataInputStream input = new DataInputStream(client.getInputStream());
                    int echoedLength = input.readInt();
                    echoed = readFrameBody(input, echoedLength);
                }
                clientClosed = client.isClosed();
                serverLength = server.get(1, TimeUnit.SECONDS);
            }
        } finally {
            listener.close();
        }
        listenerClosed = listener.isClosed();

        if (declaredLength != payload.length) {
            System.err.println("STARTER_FRAME_LENGTH expectedBytes=" + payload.length
                    + " declaredChars=" + declaredLength);
            System.exit(8);
        }

        int assertions = 0;
        assertions = check(loopback.isLoopbackAddress(), "loopback", assertions);
        assertions = check(payload.length > message.length(), "multibyte fixture", assertions);
        assertions = check(declaredLength == payload.length, "byte length prefix", assertions);
        assertions = check(serverLength == payload.length, "server length", assertions);
        assertions = check(echoed.length == payload.length, "echo length", assertions);
        assertions = check(Arrays.equals(echoed, payload), "echo bytes", assertions);
        assertions = check(message.equals(new String(echoed, StandardCharsets.UTF_8)), "UTF-8 round trip", assertions);
        assertions = check(clientClosed, "client closed", assertions);
        assertions = check(listenerClosed, "listener closed", assertions);
        assertions = check(MAX_FRAME_BYTES >= payload.length, "frame bound", assertions);
        System.out.println("challenge.assertions=" + assertions + " passed");
    }

    private static int echoOneFrame(ServerSocket listener) throws Exception {
        try (Socket peer = listener.accept()) {
            peer.setSoTimeout(500);
            DataInputStream input = new DataInputStream(peer.getInputStream());
            int length = input.readInt();
            byte[] body = readFrameBody(input, length);
            DataOutputStream output = new DataOutputStream(peer.getOutputStream());
            output.writeInt(body.length);
            output.write(body);
            output.flush();
            return body.length;
        }
    }

    private static byte[] readFrameBody(DataInputStream input, int length) throws Exception {
        if (length < 0 || length > MAX_FRAME_BYTES) {
            throw new IllegalArgumentException("invalid frame length=" + length);
        }
        byte[] body = new byte[length];
        input.readFully(body);
        return body;
    }

    private static int check(boolean condition, String message, int assertions) {
        if (!condition) {
            throw new AssertionError(message);
        }
        return assertions + 1;
    }
}
