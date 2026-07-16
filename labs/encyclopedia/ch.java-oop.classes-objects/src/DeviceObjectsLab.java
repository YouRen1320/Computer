public class DeviceObjectsLab {
    public static void main(String[] args) {
        Device pump = new Device();
        pump.code = "PUMP-01";
        pump.status = "IDLE";

        Device sensor = new Device();
        sensor.code = "SENSOR-07";
        sensor.status = "IDLE";

        pump.activate();
        sensor.rename("TEMP-08");
        sensor.deactivate();

        System.out.println("pump=" + pump.describe());
        System.out.println("sensor=" + sensor.describe());
        System.out.println("sameInstance=" + (pump == sensor));
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
