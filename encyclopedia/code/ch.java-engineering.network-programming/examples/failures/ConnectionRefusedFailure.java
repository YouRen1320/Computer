import java.net.ConnectException;
import java.net.InetAddress;
import java.net.InetSocketAddress;
import java.net.ServerSocket;
import java.net.Socket;

public final class ConnectionRefusedFailure {
    private ConnectionRefusedFailure() {
    }

    public static void main(String[] args) throws Exception {
        InetAddress loopback = InetAddress.getLoopbackAddress();
        int closedPort;
        try (ServerSocket reservation = new ServerSocket()) {
            reservation.bind(new InetSocketAddress(loopback, 0));
            closedPort = reservation.getLocalPort();
        }

        int status = 1;
        String evidence = "UNEXPECTED closed loopback listener accepted a connection";
        try (Socket socket = new Socket()) {
            socket.connect(new InetSocketAddress(loopback, closedPort), 300);
        } catch (ConnectException expected) {
            status = 5;
            evidence = "CONNECTION_REFUSED loopback="
                    + loopback.isLoopbackAddress()
                    + " listenerClosed=true cause="
                    + expected.getClass().getSimpleName();
        }

        System.err.println(evidence);
        System.exit(status);
    }
}
