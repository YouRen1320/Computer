import java.util.Scanner;

public class DeviceObjectsDemo {
    public static void main(String[] args) {
        Device pump = new Device();
        pump.code = "PUMP-01";
        pump.status = "IDLE";

        Device sensor = new Device();
        sensor.code = "SENSOR-07";
        sensor.status = "IDLE";

        System.out.println("sameInstance=" + (pump == sensor));
        pump.activate();
        System.out.println("pump=" + pump.describe());
        System.out.println("sensor=" + sensor.describe());

        sensor.rename("TEMP-08");
        System.out.println("sensor.renamed=" + sensor.describe());

        Scanner scanner = new Scanner("VALVE-09 RUNNING");
        Device parsed = new Device();
        parsed.code = scanner.next();
        parsed.status = scanner.next();
        scanner.close();

        System.out.println("parsed=" + parsed.describe());
        System.out.println("pump.still=" + pump.describe());
        System.out.println("sensor.still=" + sensor.describe());
    }

    static final class Device {
        String code;
        String status;

        void activate() {
            this.status = "ACTIVE";
        }

        void rename(String code) {
            this.code = code;
        }

        String describe() {
            return this.code + ":" + this.status;
        }
    }
}
