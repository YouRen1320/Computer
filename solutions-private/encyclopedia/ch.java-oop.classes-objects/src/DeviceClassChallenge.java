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

        check(pump != sensor, "two instances"); assertions++;
        check("IN_REPAIR".equals(pump.status), "pump status"); assertions++;
        check(pump.repairCount == 1, "pump count"); assertions++;
        check("IDLE".equals(sensor.status), "sensor status"); assertions++;
        check(sensor.repairCount == 0, "sensor count"); assertions++;
        check("TEMP-08".equals(sensor.code), "sensor code"); assertions++;
        check("PUMP-01".equals(pump.code), "pump code"); assertions++;
        check("PUMP-01:IN_REPAIR:1".equals(pump.describe()), "pump description"); assertions++;
        check("TEMP-08:IDLE:0".equals(sensor.describe()), "sensor description"); assertions++;
        check(!pump.describe().equals(sensor.describe()), "independent descriptions"); assertions++;
        System.out.println("exercise.assertions=" + assertions + " passed");
    }

    static void check(boolean condition, String message) {
        if (!condition) {
            throw new AssertionError(message);
        }
    }

    static final class Device {
        String code;
        String status;
        int repairCount;

        void startRepair() {
            this.status = "IN_REPAIR";
            this.repairCount = this.repairCount + 1;
        }

        void rename(String code) {
            this.code = code.trim();
        }

        String describe() {
            return this.code + ":" + this.status + ":" + this.repairCount;
        }
    }
}
