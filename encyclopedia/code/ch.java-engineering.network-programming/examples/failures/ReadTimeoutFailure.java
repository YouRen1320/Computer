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
    private ReadTimeoutFailure() {
    }

    public static void main(String[] args) throws Exception {
        InetAddress loopback = InetAddress.getLoopbackAddress();
        CountDownLatch accepted = new CountDownLatch(1);
        CountDownLatch releasePeer = new CountDownLatch(1);
        ExecutorService executor = Executors.newSingleThreadExecutor();
        int status = 1;
        String evidence = "UNEXPECTED silent loopback peer produced data";

        try (ServerSocket server = new ServerSocket()) {
            server.bind(new InetSocketAddress(loopback, 0));
            server.setSoTimeout(1_000);
            Future<?> peerTask = executor.submit(() -> {
                try (Socket peer = server.accept()) {
                    accepted.countDown();
                    releasePeer.await(1, TimeUnit.SECONDS);
                    return null;
                }
            });

            try (Socket client = new Socket()) {
                client.connect(new InetSocketAddress(loopback, server.getLocalPort()), 300);
                client.setSoTimeout(100);
                if (!accepted.await(1, TimeUnit.SECONDS)) {
                    throw new AssertionError("loopback peer did not accept in time");
                }
                try {
                    client.getInputStream().read();
                } catch (SocketTimeoutException expected) {
                    status = 6;
                    evidence = "READ_TIMEOUT loopback="
                            + loopback.isLoopbackAddress()
                            + " connected="
                            + client.isConnected()
                            + " cause="
                            + expected.getClass().getSimpleName();
                }
            } finally {
                releasePeer.countDown();
            }
            peerTask.get(2, TimeUnit.SECONDS);
        } finally {
            releasePeer.countDown();
            executor.shutdownNow();
            if (!executor.awaitTermination(1, TimeUnit.SECONDS)) {
                throw new AssertionError("silent peer executor did not terminate");
            }
        }

        System.err.println(evidence);
        System.exit(status);
    }
}
