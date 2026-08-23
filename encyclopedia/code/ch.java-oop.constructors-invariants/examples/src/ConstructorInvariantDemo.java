public class ConstructorInvariantDemo {
    public static void main(String[] args) {
        Device first = new Device(" PUMP-01 ", " 北区循环泵 ");
        System.out.println("created=" + first.describe());

        Device second = new Device("VALVE-02", "供水阀", "IDLE");
        System.out.println("explicit=" + second.describe());
    }

    static final class Device {
        private String status = trace("field:status", "REGISTERED");
        private String code;
        private String name;

        Device(String code, String name) {
            System.out.println("trace=constructor:body");
            this.code = requireText(code, "code");
            this.name = requireText(name, "name");
        }

        Device(String code, String name, String status) {
            this(code, name);
            System.out.println("trace=constructor:overload");
            this.status = requireStatus(status);
        }

        String describe() {
            return code + "|" + name + "|" + status;
        }

        static String trace(String step, String value) {
            System.out.println("trace=" + step);
            return value;
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
