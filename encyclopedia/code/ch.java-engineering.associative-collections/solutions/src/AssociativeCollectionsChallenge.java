import java.util.Collections;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;

public final class AssociativeCollectionsChallenge {
    private AssociativeCollectionsChallenge() {
    }

    public static void main(String[] args) {
        int assertions = 0;
        List<AssetRow> input = List.of(
                new AssetRow(new DeviceKey("PUMP-01"), "pump"),
                new AssetRow(new DeviceKey("FAN-02"), "fan"),
                new AssetRow(new DeviceKey("PUMP-01"), "pump"));
        check(input.size() == 3, "input keeps all rows"); assertions++;

        Set<DeviceKey> unique = uniqueIds(input);
        check(unique.size() == 2, "equal ids must deduplicate"); assertions++;
        check(unique.stream().map(DeviceKey::id).toList()
                .equals(List.of("PUMP-01", "FAN-02")), "first encounter order"); assertions++;
        expectUnsupported(() -> unique.add(new DeviceKey("NEW"))); assertions++;

        Map<String, Integer> counts = countCategories(input);
        check(counts.size() == 2, "two categories"); assertions++;
        check(counts.get("pump") == 2, "pump count"); assertions++;
        check(counts.get("fan") == 1, "fan count"); assertions++;
        check(requiredCount(counts, "valve") == 0, "missing count"); assertions++;
        expectUnsupported(() -> counts.put("valve", 1)); assertions++;

        Map<DeviceKey, String> stateById = new HashMap<>();
        stateById.put(new DeviceKey("PUMP-01"), "ACTIVE");
        stateById.put(new DeviceKey("FAN-02"), "CLOSED");
        DeviceKey equivalent = new DeviceKey("PUMP-01");
        check(stateById.size() == 2, "index size"); assertions++;
        check(stateById.containsKey(equivalent), "equal key hit"); assertions++;
        check("ACTIVE".equals(stateById.get(equivalent)), "equal key value"); assertions++;
        DeviceKey missing = new DeviceKey("VALVE-99");
        check(!stateById.containsKey(missing), "missing contains"); assertions++;
        check(stateById.get(missing) == null, "missing get"); assertions++;

        System.out.println("exercise.assertions=" + assertions + " passed");
    }

    static Set<DeviceKey> uniqueIds(List<AssetRow> rows) {
        Set<DeviceKey> result = new LinkedHashSet<>();
        for (AssetRow row : rows) {
            result.add(row.id());
        }
        return Collections.unmodifiableSet(result);
    }

    static Map<String, Integer> countCategories(List<AssetRow> rows) {
        Map<String, Integer> result = new LinkedHashMap<>();
        for (AssetRow row : rows) {
            result.merge(row.category(), 1, Integer::sum);
        }
        return Collections.unmodifiableMap(result);
    }

    static int requiredCount(Map<String, Integer> counts, String category) {
        return counts.getOrDefault(category, 0);
    }

    private static void expectUnsupported(Runnable action) {
        try {
            action.run();
            throw new AssertionError("expected UnsupportedOperationException");
        } catch (UnsupportedOperationException expected) {
            // Only the exception type is asserted.
        }
    }

    private static void check(boolean condition, String message) {
        if (!condition) {
            throw new AssertionError(message);
        }
    }

    record AssetRow(DeviceKey id, String category) {
    }

    record DeviceKey(String id) {
    }
}
