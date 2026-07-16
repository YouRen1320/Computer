public class ShadowingFailure {
    public static void main(String[] args) {
        Device device = new Device();
        device.code = "PUMP-01";
        device.rename("PUMP-02");

        if (!"PUMP-02".equals(device.code)) {
            System.err.println("SHADOWING_FAILURE expected=PUMP-02 actual=" + device.code);
            System.exit(4);
        }
    }

    static final class Device {
        String code;

        void rename(String code) {
            code = code;
        }
    }
}
