import java.net.InetSocketAddress;
import java.net.Socket;
import java.net.UnknownHostException;

public final class UnresolvedAddressFailure {
    private UnresolvedAddressFailure() {
    }

    public static void main(String[] args) throws Exception {
        InetSocketAddress endpoint = InetSocketAddress.createUnresolved("offline.invalid", 45_000);
        int status = 1;
        String evidence = "UNEXPECTED unresolved fixture connected";

        try (Socket socket = new Socket()) {
            // Guard before connect: an unresolved authority is rejected without invoking a resolver.
            if (endpoint.isUnresolved()) {
                throw new UnknownHostException(endpoint.getHostString());
            }
        } catch (UnknownHostException expected) {
            status = 4;
            evidence = "UNRESOLVED_ADDRESS host=offline.invalid resolved="
                    + !endpoint.isUnresolved()
                    + " stage=pre-connect cause="
                    + expected.getClass().getSimpleName();
        }

        System.err.println(evidence);
        System.exit(status);
    }
}
