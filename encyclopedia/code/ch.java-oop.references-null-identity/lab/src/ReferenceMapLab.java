public class ReferenceMapLab {
    public static void main(String[] args) {
        Device primary = device("PUMP-01", "IDLE");
        Device alias = primary;
        Device peer = device("PUMP-01", "IDLE");
        Device missing = null;

        alias.status = "RUNNING";

        System.out.println("alias.sameIdentity=" + (primary == alias));
        System.out.println("peer.sameIdentity=" + (primary == peer));
        System.out.println("primary.status=" + primary.status);
        System.out.println("peer.status=" + peer.status);
        System.out.println("missing.route=" + route(missing));
    }

    static Device device(String code, String status) {
        Device result = new Device();
        result.code = code;
        result.status = status;
        return result;
    }

    static String route(Device device) {
        if (device == null) {
            return "REJECT_MISSING_DEVICE";
        }
        return "ACCEPT:" + device.code;
    }

    static final class Device {
        String code;
        String status;
    }
}
