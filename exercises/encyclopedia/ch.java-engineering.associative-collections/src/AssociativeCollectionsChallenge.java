import java.util.Collections;
import java.util.HashMap;
import java.util.HashSet;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.Set;

public final class AssociativeCollectionsChallenge {
    private AssociativeCollectionsChallenge() {
    }

    public static void main(String[] args) {
        int assertions = 0;
        List<AssetRow> input = List.of(
                new AssetRow(new DeviceKey("PUMP-01", 1), "pump"),
                new AssetRow(new DeviceKey("FAN-02", 7), "fan"),
                new AssetRow(new DeviceKey("PUMP-01", 2), "pump"));
        check(input.size() == 3, "input keeps all rows"); assertions++;

        Set<DeviceKey> unique = uniqueIds(input);
        check(unique.size() == 2, "equal ids must deduplicate"); assertions++;
        check(unique.stream().map(DeviceKey::id).toList()
                .equals(List.of("PUMP-01", "FAN-02")), "first encounter order"); assertions++;
        expectUnsupported(() -> unique.add(new DeviceKey("NEW", 9))); assertions++;

        Map<String, Integer> counts = countCategories(input);
        check(counts.size() == 2, "two categories"); assertions++;
        check(counts.get("pump") == 2, "pump count"); assertions++;
        check(counts.get("fan") == 1, "fan count"); assertions++;
        check(requiredCount(counts, "valve") == 0, "missing count"); assertions++;
        expectUnsupported(() -> counts.put("valve", 1)); assertions++;

        Map<DeviceKey, String> stateById = new HashMap<>();
        stateById.put(new DeviceKey("PUMP-01", 1), "OPEN");
        stateById.put(new DeviceKey("FAN-02", 7), "CLOSED");
        DeviceKey equivalent = new DeviceKey("PUMP-01", 2);
        check(stateById.size() == 2, "index size"); assertions++;
        check(stateById.containsKey(equivalent), "equal key hit"); assertions++;
        check("OPEN".equals(stateById.get(equivalent)), "equal key value"); assertions++;
        DeviceKey missing = new DeviceKey("VALVE-99", 3);
        check(!stateById.containsKey(missing), "missing contains"); assertions++;
        check(stateById.get(missing) == null, "missing get"); assertions++;

        System.out.println("exercise.assertions=" + assertions + " passed");
    }

    // TODO 2：选择保留首次 encounter order 的 Set 实现，并保持返回值不可修改。
    static Set<DeviceKey> uniqueIds(List<AssetRow> rows) {
        Set<DeviceKey> result = new HashSet<>();
        for (AssetRow row : rows) {
            result.add(row.id());
        }
        return Collections.unmodifiableSet(result);
    }

    // TODO 3：相同类别必须累加，不是每次覆盖为 1。
    static Map<String, Integer> countCategories(List<AssetRow> rows) {
        Map<String, Integer> result = new LinkedHashMap<>();
        for (AssetRow row : rows) {
            result.put(row.category(), 1);
        }
        return Collections.unmodifiableMap(result);
    }

    // TODO 4：显式处理缺失，不让 null 自动拆箱。
    static int requiredCount(Map<String, Integer> counts, String category) {
        return counts.get(category);
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

    // TODO 1：相等只由不可变 id 决定，hashCode 必须遵守同一合同。
    static final class DeviceKey {
        private final String id;
        private final int wrongHash;

        DeviceKey(String id, int wrongHash) {
            this.id = id;
            this.wrongHash = wrongHash;
        }

        String id() {
            return id;
        }

        @Override
        public boolean equals(Object other) {
            return this == other || other instanceof DeviceKey that
                    && Objects.equals(id, that.id);
        }

        @Override
        public int hashCode() {
            return wrongHash;
        }
    }
}
