public class ReferenceChallenge {
    public static void main(String[] args) {
        int assertions = 0;
        Device primary = device("PUMP-01", "IDLE");
        Device alias = primary;
        Device peer = device("PUMP-01", "IDLE");
        Device missing = null;

        check(primary == alias, "alias must share identity");
        assertions++;

        // TODO 1：不能用 == 证明两个不同对象的字段值相同。
        check(primary == peer, "peer must have equivalent state");
        assertions++;

        alias.status = "RUNNING";
        check("RUNNING".equals(primary.status), "alias write must be visible");
        assertions++;
        check("IDLE".equals(peer.status), "peer must remain independent");
        assertions++;

        check(missing == null, "missing must be null");
        assertions++;
        // TODO 2：先判空；不要直接解引用 missing。
        check(missing.code.isEmpty(), "missing must route safely");
        assertions++;

        check(primary != peer, "equivalent state does not imply same identity");
        assertions++;
        check("PUMP-01".equals(peer.code), "peer code");
        assertions++;
        System.out.println("challenge.assertions=" + assertions + " passed");
    }

    static Device device(String code, String status) {
        Device result = new Device();
        result.code = code;
        result.status = status;
        return result;
    }

    static void check(boolean condition, String message) {
        if (!condition) {
            System.err.println("CHALLENGE_FAILURE " + message);
            System.exit(5);
        }
    }

    static final class Device {
        String code;
        String status;
    }
}
