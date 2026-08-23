import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.TreeSet;
import java.util.stream.Collectors;

public final class AssociativeCollectionsDemo {
    private AssociativeCollectionsDemo() {
    }

    public static void main(String[] args) {
        List<ImportRow> input = List.of(
                new ImportRow(new DeviceId("PUMP-01"), "pump"),
                new ImportRow(new DeviceId("FAN-02"), "fan"),
                new ImportRow(new DeviceId("PUMP-01"), "pump"));
        System.out.println("input.rows=" + input.size());
        System.out.println("input.ids=" + input.stream()
                .map(row -> row.id().value()).collect(Collectors.joining(",")));

        Set<DeviceId> unique = new LinkedHashSet<>();
        Map<String, Integer> counts = new LinkedHashMap<>();
        for (ImportRow row : input) {
            unique.add(row.id());
            counts.merge(row.category(), 1, Integer::sum);
        }
        System.out.println("unique.size=" + unique.size());
        System.out.println("unique.ids=" + unique.stream()
                .map(DeviceId::value).collect(Collectors.joining(",")));
        System.out.println("category.counts=" + counts.entrySet().stream()
                .map(entry -> entry.getKey() + ":" + entry.getValue())
                .collect(Collectors.joining(",")));

        Map<DeviceId, String> stateById = new HashMap<>();
        DeviceId stored = new DeviceId("PUMP-01");
        DeviceId equivalentLookup = new DeviceId("PUMP-01");
        stateById.put(stored, "ACTIVE");
        System.out.println("map.equalKey.hit=" + stateById.containsKey(equivalentLookup));
        System.out.println("map.equalKey.state=" + stateById.get(equivalentLookup));
        DeviceId missing = new DeviceId("VALVE-99");
        System.out.println("missing.contains=" + stateById.containsKey(missing));
        System.out.println("missing.get=" + stateById.get(missing));

        Set<DeviceId> sorted = new TreeSet<>((left, right) -> left.value().compareTo(right.value()));
        sorted.addAll(unique);
        System.out.println("sorted.ids=" + sorted.stream()
                .map(DeviceId::value).collect(Collectors.joining(",")));
    }

    record DeviceId(String value) {
    }

    record ImportRow(DeviceId id, String category) {
    }
}
