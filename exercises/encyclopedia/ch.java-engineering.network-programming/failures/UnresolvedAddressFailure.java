import java.net.InetSocketAddress;
import java.net.Socket;
import java.net.UnknownHostException;

public final class UnresolvedAddressFailure {
    public static void main(String[] args) throws Exception {
        InetSocketAddress endpoint = InetSocketAddress.createUnresolved("offline.invalid", 42424);
        Socket socket = new Socket();
        boolean classified = false;
        try {
            if (endpoint.isUnresolved()) {
                throw new UnknownHostException(endpoint.getHostString());
            }
        } catch (UnknownHostException expected) {
            classified = endpoint.isUnresolved();
        } finally {
            socket.close();
        }
        if (!classified || !socket.isClosed()) {
            throw new AssertionError("unresolved address was not classified and cleaned up");
        }
        System.err.println("UNRESOLVED_ADDRESS stage=pre-connect unresolved=true exception=UnknownHostException closed=true");
        System.exit(4);
    }
}
