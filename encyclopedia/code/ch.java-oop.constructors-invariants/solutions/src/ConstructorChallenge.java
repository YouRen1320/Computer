public class ConstructorChallenge {
    public static void main(String[] args) {
        int assertions = 0;
        Device pump = new Device(" pump-01 ", " 北区循环泵 ");
        check("PUMP-01".equals(pump.code), "normalized code"); assertions++;
        check("北区循环泵".equals(pump.name), "normalized name"); assertions++;
        check("REGISTERED".equals(pump.status), "default status"); assertions++;
        check(pump.repairCount == 0, "default repair count"); assertions++;
        expectInvalid(null, "name"); assertions++;
        expectInvalid("", "name"); assertions++;
        expectInvalid(" ", "name"); assertions++;
        expectInvalid("X", null); assertions++;
        expectInvalid("X", " "); assertions++;
        Device second = new Device("VALVE-02", "供水阀");
        check(pump != second, "independent objects"); assertions++;
        System.out.println("challenge.assertions=" + assertions + " passed");
    }

    static void expectInvalid(String code, String name) {
        try {
            new Device(code, name);
            throw new AssertionError("invalid construction accepted");
        } catch (IllegalArgumentException expected) {
            // Expected.
        }
    }

    static void check(boolean condition, String message) {
        if (!condition) throw new AssertionError(message);
    }

    static final class Device {
        private final String code;
        private final String name;
        private String status = "REGISTERED";
        private int repairCount;

        Device(String code, String name) {
            String normalizedCode = requireText(code, "code").toUpperCase();
            String normalizedName = requireText(name, "name");
            this.code = normalizedCode;
            this.name = normalizedName;
        }

        static String requireText(String value, String field) {
            if (value == null || value.trim().isEmpty()) {
                throw new IllegalArgumentException(field + " must not be blank");
            }
            return value.trim();
        }
    }
}
