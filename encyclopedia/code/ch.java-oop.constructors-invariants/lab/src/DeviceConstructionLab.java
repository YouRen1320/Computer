public class DeviceConstructionLab {
    public static void main(String[] args) {
        Device pump = new Device(" pump-01 ", " 北区循环泵 ");
        Device valve = new Device("valve-02", "供水阀", "IDLE");
        System.out.println("pump=" + pump.describe());
        System.out.println("valve=" + valve.describe());
    }

    static final class Device {
        private String status = "REGISTERED";
        private final String code;
        private final String name;

        Device(String code, String name) {
            this.code = requireText(code, "code").toUpperCase();
            this.name = requireText(name, "name");
        }

        Device(String code, String name, String status) {
            this(code, name);
            this.status = requireStatus(status);
        }

        String describe() {
            return code + "|" + name + "|" + status;
        }

        static String requireText(String value, String field) {
            if (value == null || value.trim().isEmpty()) {
                throw new IllegalArgumentException(field + " must not be blank");
            }
            return value.trim();
        }

        static String requireStatus(String value) {
            String normalized = requireText(value, "status");
            if (!"REGISTERED".equals(normalized) && !"IDLE".equals(normalized)) {
                throw new IllegalArgumentException("unsupported status");
            }
            return normalized;
        }
    }
}
