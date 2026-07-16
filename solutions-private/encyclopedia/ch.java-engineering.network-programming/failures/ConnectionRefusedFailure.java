import java.net.ConnectException;
import java.net.InetAddress;
import java.net.InetSocketAddress;
import java.net.ServerSocket;
import java.net.Socket;

public final class ConnectionRefusedFailure {
    public static void main(String[] args) throws Exception {
        InetAddress loopback = InetAddress.getLoopbackAddress();
        int unusedPort;
        try (ServerSocket reservation = new ServerSocket()) {
            reservation.bind(new InetSocketAddress(loopback, 0));
            unusedPort = reservation.getLocalPort();
        }
        Socket socket = new Socket();
        boolean refused = false;
        try (socket) {
            socket.connect(new InetSocketAddress(loopback, unusedPort), 300);
        } catch (ConnectException expected) {
            refused = true;
        }
        if (!refused || !socket.isClosed()) {
            throw new AssertionError("connection refusal or cleanup failed");
        }
        System.err.println("CONNECTION_REFUSED layer=tcp exception=ConnectException closed=true");
        System.exit(5);
    }
}
