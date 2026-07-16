public class ReferenceMapOracle {
    public static void main(String[] args) {
        int assertions = 0;
        Device primary = device("PUMP-01", "IDLE");
        Device alias = primary;
        Device peer = device("PUMP-01", "IDLE");
        Device missing = null;

        assert primary == alias;
        assertions++;
        assert primary != peer;
        assertions++;
        assert sameFields(primary, peer);
        assertions++;

        alias.status = "RUNNING";
        assert "RUNNING".equals(primary.status);
        assertions++;
        assert "IDLE".equals(peer.status);
        assertions++;

        assert missing == null;
        assertions++;
        assert missing != primary;
        assertions++;
        assert "REJECT_MISSING_DEVICE".equals(route(missing));
        assertions++;
        assert "ACCEPT:PUMP-01".equals(route(primary));
        assertions++;
        assert !"".equals(route(missing));
        assertions++;

        System.out.println("assertions=" + assertions + " passed");
    }

    static Device device(String code, String status) {
        Device result = new Device();
        result.code = code;
        result.status = status;
        return result;
    }

    static boolean sameFields(Device left, Device right) {
        return left.code.equals(right.code) && left.status.equals(right.status);
    }

    static String route(Device device) {
        return device == null ? "REJECT_MISSING_DEVICE" : "ACCEPT:" + device.code;
    }

    static final class Device {
        String code;
        String status;
    }
}
