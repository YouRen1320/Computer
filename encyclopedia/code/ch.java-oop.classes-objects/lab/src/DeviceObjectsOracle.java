public class DeviceObjectsOracle {
    public static void main(String[] args) {
        int assertions = 0;
        Device pump = new Device();
        pump.code = "PUMP-01";
        pump.status = "IDLE";
        Device sensor = new Device();
        sensor.code = "SENSOR-07";
        sensor.status = "IDLE";

        assert pump != sensor;
        assertions++;
        assert "PUMP-01".equals(pump.code);
        assertions++;
        assert "SENSOR-07".equals(sensor.code);
        assertions++;

        pump.activate();
        assert "ACTIVE".equals(pump.status);
        assertions++;
        assert "IDLE".equals(sensor.status);
        assertions++;

        sensor.rename("TEMP-08");
        assert "TEMP-08".equals(sensor.code);
        assertions++;
        assert "PUMP-01".equals(pump.code);
        assertions++;

        sensor.deactivate();
        assert "OFFLINE".equals(sensor.status);
        assertions++;
        assert "PUMP-01:ACTIVE".equals(pump.describe());
        assertions++;
        assert "TEMP-08:OFFLINE".equals(sensor.describe());
        assertions++;

        System.out.println("assertions=" + assertions + " passed");
    }

    static final class Device {
        String code;
        String status;

        void activate() {
            this.status = "ACTIVE";
        }

        void deactivate() {
            this.status = "OFFLINE";
        }

        void rename(String code) {
            this.code = code;
        }

        String describe() {
            return this.code + ":" + this.status;
        }
    }
}
