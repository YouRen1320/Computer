import java.util.Comparator;
import java.util.Set;
import java.util.TreeSet;

public final class ComparatorCollisionFailure {
    private ComparatorCollisionFailure() {
    }

    public static void main(String[] args) {
        Set<DeviceKey> devices = new TreeSet<>(Comparator.comparing(DeviceKey::site));
        devices.add(new DeviceKey("SITE-A", "PUMP-01"));
        devices.add(new DeviceKey("SITE-A", "FAN-02"));
        if (devices.size() == 1) {
            throw new IllegalStateException("COMPARATOR_COLLISION");
        }
    }

    private record DeviceKey(String site, String id) {
    }
}
