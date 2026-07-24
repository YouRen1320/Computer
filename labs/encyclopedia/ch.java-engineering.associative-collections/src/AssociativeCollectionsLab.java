import java.util.Collections;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;

final class AssociativeCollectionsLab {
    private AssociativeCollectionsLab() {
    }

    static Set<DeviceId> uniqueIds(List<ImportRow> rows) {
        Set<DeviceId> result = new LinkedHashSet<>();
        for (ImportRow row : rows) {
            result.add(row.id());
        }
        return Collections.unmodifiableSet(result);
    }

    static Map<String, Integer> countCategories(List<ImportRow> rows) {
        Map<String, Integer> result = new LinkedHashMap<>();
        for (ImportRow row : rows) {
            result.merge(row.category(), 1, Integer::sum);
        }
        return Collections.unmodifiableMap(result);
    }

    static Map<DeviceId, Device> indexDevices(List<ImportRow> rows) {
        Map<DeviceId, Device> result = new HashMap<>();
        for (ImportRow row : rows) {
            result.put(row.id(), new Device(row.id(), row.category(), "ACTIVE"));
        }
        return result;
    }

    record DeviceId(String value) {
    }

    record ImportRow(DeviceId id, String category) {
    }

    record Device(DeviceId id, String category, String state) {
    }
}
