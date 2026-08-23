public class DeviceClassChallenge {
    public static void main(String[] args) {
        int assertions = 0;
        Device pump = new Device();
        pump.code = "PUMP-01";
        pump.status = "IDLE";

        Device sensor = new Device();
        sensor.code = "SENSOR-07";
        sensor.status = "IDLE";

        pump.startRepair();
        sensor.rename(" TEMP-08 ");

        check(pump != sensor, "two new expressions must create different instances");
        assertions++;
        check("IN_REPAIR".equals(pump.status), "pump status");
        assertions++;
        check(pump.repairCount == 1, "pump repair count");
        assertions++;
        check("IDLE".equals(sensor.status), "sensor status must be independent");
        assertions++;
        check(sensor.repairCount == 0, "sensor count must be independent");
        assertions++;
        check("TEMP-08".equals(sensor.code), "rename must update field");
        assertions++;
        check("PUMP-01".equals(pump.code), "pump code must not change");
        assertions++;
        check("PUMP-01:IN_REPAIR:1".equals(pump.describe()), "pump description");
        assertions++;
        check("TEMP-08:IDLE:0".equals(sensor.describe()), "sensor description");
        assertions++;
        check(!pump.describe().equals(sensor.describe()), "independent descriptions");
        assertions++;
        System.out.println("exercise.assertions=" + assertions + " passed");
    }

    static void check(boolean condition, String message) {
        if (!condition) {
            System.err.println("CHALLENGE_FAILURE " + message);
            System.exit(7);
        }
    }

    static final class Device {
        String code;
        String status;
        int repairCount;

        void startRepair() {
            String status = "IN_REPAIR"; // TODO 1：修改当前实例字段。
            int repairCount = this.repairCount + 1; // TODO 2：结果要写回字段。
        }

        void rename(String code) {
            code = code.trim(); // TODO 3：处理后的值要写入当前实例字段。
        }

        String describe() {
            return this.code + ":" + this.status + ":" + this.repairCount;
        }
    }
}
