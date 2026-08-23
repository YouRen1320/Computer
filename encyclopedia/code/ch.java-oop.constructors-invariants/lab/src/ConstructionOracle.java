public class ConstructionOracle {
    public static void main(String[] args) {
        int assertions = 0;
        Device pump = new Device(" pump-01 ", " 北区循环泵 ");
        check("PUMP-01".equals(pump.code), "normalized code"); assertions++;
        check("北区循环泵".equals(pump.name), "normalized name"); assertions++;
        check("REGISTERED".equals(pump.status), "default status"); assertions++;

        Device valve = new Device("valve-02", "供水阀", "IDLE");
        check("VALVE-02".equals(valve.code), "overload code"); assertions++;
        check("供水阀".equals(valve.name), "overload name"); assertions++;
        check("IDLE".equals(valve.status), "explicit status"); assertions++;
        check(pump != valve, "independent identities"); assertions++;
        TraceDevice.trace = "";
        new TraceDevice();
        check("field:first>field:second>constructor:body".equals(TraceDevice.trace), "initialization order"); assertions++;

        expectInvalid(null, "name", "null code"); assertions++;
        expectInvalid(" ", "name", "blank code"); assertions++;
        expectInvalid("X", null, "null name"); assertions++;
        expectInvalid("X", " ", "blank name"); assertions++;
        expectInvalidStatus("RETIRED"); assertions++;
        System.out.println("assertions=" + assertions + " passed");
    }

    static void expectInvalid(String code, String name, String message) {
        try {
            new Device(code, name);
            throw new AssertionError(message + " accepted");
        } catch (IllegalArgumentException expected) {
            // Expected rejection is the oracle.
        }
    }

    static void expectInvalidStatus(String status) {
        try {
            new Device("X", "name", status);
            throw new AssertionError("unsupported status accepted");
        } catch (IllegalArgumentException expected) {
            // Expected rejection is the oracle.
        }
    }

    static void check(boolean condition, String message) {
        if (!condition) throw new AssertionError(message);
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

    static final class TraceDevice {
        static String trace = "";
        private String first = mark("field:first");
        private String second = mark("field:second");

        TraceDevice() {
            mark("constructor:body");
        }

        static String mark(String step) {
            trace = trace.isEmpty() ? step : trace + ">" + step;
            return step;
        }
    }
}
