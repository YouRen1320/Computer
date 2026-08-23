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
        if (!condition) {
            System.err.println("CHALLENGE_FAILURE " + message);
            System.exit(7);
        }
    }

    static final class Device {
        private String code;
        private String name;
        private String status = "REGISTERED";
        private int repairCount;

        Device(String code, String name) {
            code = code; // TODO 1：校验并把规范化编码写入 this.code。
            name = name; // TODO 2：校验并把规范化名称写入 this.name。
            // TODO 3：null、空串和全空白必须抛 IllegalArgumentException。
        }
    }
}
