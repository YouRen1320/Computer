import java.util.ArrayList;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.TreeSet;
import java.util.stream.Collectors;

public final class AssociativeCollectionsOracle {
    private AssociativeCollectionsOracle() {
    }

    public static void main(String[] args) {
        int assertions = 0;
        List<AssociativeCollectionsLab.ImportRow> input = List.of(
                row("PUMP-01", "pump"),
                row("FAN-02", "fan"),
                row("PUMP-01", "pump"));
        check(input.size() == 3, "input keeps duplicate row"); assertions++;
        check(input.getFirst().id().equals(input.getLast().id()), "equal endpoint ids"); assertions++;
        check(input.getFirst().id() != input.getLast().id(), "different references"); assertions++;

        Set<AssociativeCollectionsLab.DeviceId> unique = AssociativeCollectionsLab.uniqueIds(input);
        List<String> uniqueValues = unique.stream()
                .map(AssociativeCollectionsLab.DeviceId::value).toList();
        check(unique.size() == 2, "set deduplicates"); assertions++;
        check(uniqueValues.equals(List.of("PUMP-01", "FAN-02")), "first encounter order"); assertions++;
        expectUnsupported(() -> unique.add(new AssociativeCollectionsLab.DeviceId("NEW"))); assertions++;

        Map<String, Integer> counts = AssociativeCollectionsLab.countCategories(input);
        check(counts.size() == 2, "category count size"); assertions++;
        check(counts.get("pump") == 2, "pump count"); assertions++;
        check(counts.get("fan") == 1, "fan count"); assertions++;
        check(counts.getOrDefault("valve", 0) == 0, "missing count default"); assertions++;
        expectUnsupported(() -> counts.put("valve", 1)); assertions++;

        Map<AssociativeCollectionsLab.DeviceId, AssociativeCollectionsLab.Device> index =
                AssociativeCollectionsLab.indexDevices(input);
        AssociativeCollectionsLab.DeviceId equivalent = new AssociativeCollectionsLab.DeviceId("PUMP-01");
        check(index.size() == 2, "index replaces equal key"); assertions++;
        check(index.containsKey(equivalent), "equivalent key hit"); assertions++;
        check("OPEN".equals(index.get(equivalent).state()), "equivalent key value"); assertions++;

        AssociativeCollectionsLab.DeviceId missing = new AssociativeCollectionsLab.DeviceId("VALVE-99");
        check(!index.containsKey(missing), "missing contains"); assertions++;
        check(index.get(missing) == null, "missing get"); assertions++;
        Map<String, String> nullable = new HashMap<>();
        nullable.put("present", null);
        check(nullable.containsKey("present"), "present null contains"); assertions++;
        check(nullable.get("present") == null, "present null get"); assertions++;

        Set<CollisionKey> collisions = new HashSet<>();
        collisions.add(new CollisionKey("A"));
        collisions.add(new CollisionKey("B"));
        check(collisions.size() == 2, "hash collision resolved by equals"); assertions++;

        Set<String> sorted = new TreeSet<>(uniqueValues);
        check(new ArrayList<>(sorted).equals(List.of("FAN-02", "PUMP-01")), "tree order"); assertions++;

        System.out.println("report.input=" + input.stream()
                .map(value -> value.id().value()).collect(Collectors.joining(",")));
        System.out.println("report.unique=" + String.join(",", uniqueValues));
        System.out.println("report.counts=" + counts.entrySet().stream()
                .map(entry -> entry.getKey() + ":" + entry.getValue())
                .collect(Collectors.joining(",")));
        System.out.println("report.equalKey=hit:" + index.get(equivalent).state());
        System.out.println("report.missing=contains:" + index.containsKey(missing) + ",get:" + index.get(missing));
        System.out.println("assertions=" + assertions + " passed");
    }

    private static AssociativeCollectionsLab.ImportRow row(String id, String category) {
        return new AssociativeCollectionsLab.ImportRow(
                new AssociativeCollectionsLab.DeviceId(id), category);
    }

    private static void expectUnsupported(Runnable action) {
        try {
            action.run();
            throw new AssertionError("expected UnsupportedOperationException");
        } catch (UnsupportedOperationException expected) {
            // The exception type is the stable oracle; message text is not.
        }
    }

    private static void check(boolean condition, String message) {
        if (!condition) {
            throw new AssertionError(message);
        }
    }

    private record CollisionKey(String value) {
        @Override
        public int hashCode() {
            return 7;
        }
    }
}
