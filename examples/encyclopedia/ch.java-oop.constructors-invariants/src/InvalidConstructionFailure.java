public class InvalidConstructionFailure {
    public static void main(String[] args) {
        new Device("   ", "北区循环泵");
    }

    static final class Device {
        private final String code;
        private final String name;

        Device(String code, String name) {
            this.code = requireText(code, "code");
            this.name = requireText(name, "name");
        }

        static String requireText(String value, String field) {
            if (value == null || value.trim().isEmpty()) {
                throw new IllegalArgumentException(field + " must not be blank");
            }
            return value.trim();
        }
    }
}
