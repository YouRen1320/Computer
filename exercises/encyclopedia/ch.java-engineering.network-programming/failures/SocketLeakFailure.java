import java.net.InetAddress;
import java.net.InetSocketAddress;
import java.net.ServerSocket;
import java.net.Socket;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;
import java.util.concurrent.TimeUnit;

public final class SocketLeakFailure {
    public static void main(String[] args) throws Exception {
        InetAddress loopback = InetAddress.getLoopbackAddress();
        CountDownLatch accepted = new CountDownLatch(1);
        CountDownLatch release = new CountDownLatch(1);
        Socket client = new Socket();
        boolean observedClosed;

        try (ServerSocket listener = new ServerSocket()) {
            listener.bind(new InetSocketAddress(loopback, 0));
            listener.setSoTimeout(1_000);
            try (ExecutorService executor = Executors.newSingleThreadExecutor()) {
                Future<Boolean> peer = executor.submit(() -> {
                    try (Socket acceptedSocket = listener.accept()) {
                        accepted.countDown();
                        return release.await(1, TimeUnit.SECONDS);
                    }
                });
                client.connect(new InetSocketAddress(loopback, listener.getLocalPort()), 300);
                if (!accepted.await(1, TimeUnit.SECONDS)) {
                    throw new AssertionError("peer did not accept");
                }
                observedClosed = client.isClosed();
                client.close();
                release.countDown();
                if (!peer.get(1, TimeUnit.SECONDS)) {
                    throw new AssertionError("peer was not released");
                }
            }
        } finally {
            client.close();
            release.countDown();
        }
        if (observedClosed || !client.isClosed()) {
            throw new AssertionError("leak evidence or cleanup state is wrong");
        }
        System.err.println("SOCKET_LEAK observedClosed=false cleanupClosed=true");
        System.exit(7);
    }
}
