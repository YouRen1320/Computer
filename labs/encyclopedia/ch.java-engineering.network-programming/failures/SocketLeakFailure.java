import java.net.InetAddress;
import java.net.InetSocketAddress;
import java.net.ServerSocket;
import java.net.Socket;

public final class SocketLeakFailure {
    private SocketLeakFailure() {
    }

    public static void main(String[] args) throws Exception {
        InetAddress loopback = InetAddress.getLoopbackAddress();
        boolean observedClosed;
        boolean cleanupClosed;

        try (ServerSocket server = new ServerSocket(); Socket client = new Socket()) {
            server.bind(new InetSocketAddress(loopback, 0));
            client.connect(new InetSocketAddress(loopback, server.getLocalPort()), 300);
            observedClosed = client.isClosed();
            client.close();
            cleanupClosed = client.isClosed();
        }

        int status = !observedClosed && cleanupClosed ? 7 : 1;
        System.err.printf("SOCKET_LEAK observedClosed=%s cleanupClosed=%s%n", observedClosed, cleanupClosed);
        System.exit(status);
    }
}
