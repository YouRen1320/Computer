public class LocalShadowingFailure {
    public static void main(String[] args) {
        Device sensor = new Device();
        sensor.code = "SENSOR-07";
        sensor.rename("TEMP-08");

        if (!"TEMP-08".equals(sensor.code)) {
            System.err.println("LOCAL_SHADOWING expected=TEMP-08 actual=" + sensor.code);
            System.exit(6);
        }
    }

    static final class Device {
        String code;

        void rename(String code) {
            String normalized = code.trim();
            code = normalized;
        }
    }
}
