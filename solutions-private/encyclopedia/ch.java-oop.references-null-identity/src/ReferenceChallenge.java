public class ReferenceChallenge {
    public static void main(String[] args) {
        int assertions = 0;
        Device primary = device("PUMP-01", "IDLE");
        Device alias = primary;
        Device peer = device("PUMP-01", "IDLE");
        Device missing = null;

        check(primary == alias, "alias must share identity");
        assertions++;
        check(sameFields(primary, peer), "peer must have equivalent state");
        assertions++;

        alias.status = "RUNNING";
        check("RUNNING".equals(primary.status), "alias write must be visible");
        assertions++;
        check("IDLE".equals(peer.status), "peer must remain independent");
        assertions++;

        check(missing == null, "missing must be null");
        assertions++;
        check("REJECT_MISSING_DEVICE".equals(route(missing)), "missing must route safely");
        assertions++;
        check(primary != peer, "equivalent state does not imply same identity");
        assertions++;
        check("PUMP-01".equals(peer.code), "peer code");
        assertions++;
        System.out.println("challenge.assertions=" + assertions + " passed");
    }

    static boolean sameFields(Device left, Device right) {
        return left.code.equals(right.code) && left.status.equals(right.status);
    }

    static String route(Device device) {
        return device == null ? "REJECT_MISSING_DEVICE" : "ACCEPT:" + device.code;
    }

    static Device device(String code, String status) {
        Device result = new Device();
        result.code = code;
        result.status = status;
        return result;
    }

    static void check(boolean condition, String message) {
        if (!condition) {
            throw new AssertionError(message);
        }
    }

    static final class Device {
        String code;
        String status;
    }
}
