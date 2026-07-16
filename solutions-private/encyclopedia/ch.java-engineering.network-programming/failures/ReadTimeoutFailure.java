import java.net.InetAddress;
import java.net.InetSocketAddress;
import java.net.ServerSocket;
import java.net.Socket;
import java.net.SocketTimeoutException;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;
import java.util.concurrent.TimeUnit;

public final class ReadTimeoutFailure {
    public static void main(String[] args) throws Exception {
        InetAddress loopback = InetAddress.getLoopbackAddress();
        CountDownLatch accepted = new CountDownLatch(1);
        CountDownLatch release = new CountDownLatch(1);
        boolean timedOut = false;
        boolean clientClosed;
        try (ServerSocket listener = new ServerSocket()) {
            listener.bind(new InetSocketAddress(loopback, 0));
            listener.setSoTimeout(1_000);
            try (ExecutorService executor = Executors.newSingleThreadExecutor()) {
                Future<Boolean> peer = executor.submit(() -> {
                    try (Socket socket = listener.accept()) {
                        accepted.countDown();
                        return release.await(1, TimeUnit.SECONDS);
                    }
                });
                Socket client = new Socket();
                try (client) {
                    client.connect(new InetSocketAddress(loopback, listener.getLocalPort()), 300);
                    client.setSoTimeout(80);
                    if (!accepted.await(1, TimeUnit.SECONDS)) {
                        throw new AssertionError("peer did not accept");
                    }
                    try {
                        client.getInputStream().read();
                    } catch (SocketTimeoutException expected) {
                        timedOut = true;
                    }
                } finally {
                    release.countDown();
                }
                clientClosed = client.isClosed();
                if (!peer.get(1, TimeUnit.SECONDS)) {
                    throw new AssertionError("peer was not released");
                }
            }
        }
        if (!timedOut || !clientClosed) {
            throw new AssertionError("read timeout or cleanup failed");
        }
        System.err.println("READ_TIMEOUT phase=read exception=SocketTimeoutException closed=true");
        System.exit(6);
    }
}
