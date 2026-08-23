import java.util.ArrayList;
import java.util.Collections;
import java.util.LinkedHashMap;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;

public final class ComplexityAlgorithmsChallenge {
    private ComplexityAlgorithmsChallenge() {
    }

    public static void main(String[] args) {
        int assertions = 0;
        List<Event> input = List.of(
                new Event("A", 1), new Event("B", 2), new Event("A", 3),
                new Event("C", 4), new Event("D", 5), new Event("B", 6));
        check(input.size() == 6, "audit input keeps duplicates"); assertions++;

        DedupReport dedup = deduplicate(input);
        check(dedup.uniqueIds().equals(List.of("A", "B", "C", "D")), "first encounter unique ids"); assertions++;
        check(dedup.operations() == 6, "one membership operation per input"); assertions++;
        expectUnsupported(() -> dedup.uniqueIds().add("E")); assertions++;
        check(input.get(2).id().equals("A") && input.get(5).id().equals("B"), "input duplicates preserved"); assertions++;

        List<Integer> querySource = List.of(9, 1, 7, 3, 5);
        QueryReport queries = querySortedSnapshot(querySource, List.of(1, 5, 8));
        check(queries.positions().equals(List.of(0, 2, -5)), "binary search positions"); assertions++;
        check(queries.sortCalls() == 1, "one reusable sort"); assertions++;
        expectUnsupported(() -> queries.positions().add(99)); assertions++;
        check(querySource.equals(List.of(9, 1, 7, 3, 5)), "query source unchanged"); assertions++;

        Map<String, Event> index = indexLatestById(input);
        check(index.size() == 4, "index unique key count"); assertions++;
        check(index.get("A").sequence() == 3, "latest A wins"); assertions++;
        check(index.get("B").sequence() == 6, "latest B wins"); assertions++;
        check(!index.containsKey("MISSING"), "missing contains"); assertions++;
        check(index.get("MISSING") == null, "missing get"); assertions++;
        expectUnsupported(() -> index.put("E", new Event("E", 7))); assertions++;

        System.out.println("exercise.assertions=" + assertions + " passed");
    }

    static DedupReport deduplicate(List<Event> input) {
        Set<String> unique = new LinkedHashSet<>();
        long operations = 0;
        for (Event event : input) {
            operations++;
            unique.add(event.id());
        }
        return new DedupReport(List.copyOf(unique), operations);
    }

    static QueryReport querySortedSnapshot(List<Integer> source, List<Integer> targets) {
        List<Integer> sorted = new ArrayList<>(source);
        sorted.sort(Integer::compare);
        List<Integer> positions = new ArrayList<>();
        for (Integer target : targets) {
            positions.add(Collections.binarySearch(sorted, target));
        }
        return new QueryReport(List.copyOf(positions), 1);
    }

    static Map<String, Event> indexLatestById(List<Event> input) {
        Map<String, Event> result = new LinkedHashMap<>();
        for (Event event : input) {
            result.put(event.id(), event);
        }
        return Map.copyOf(result);
    }

    private static void expectUnsupported(Runnable action) {
        try {
            action.run();
            throw new AssertionError("expected UnsupportedOperationException");
        } catch (UnsupportedOperationException expected) {
            // Only the exception type is stable evidence.
        }
    }

    private static void check(boolean condition, String message) {
        if (!condition) {
            throw new AssertionError(message);
        }
    }

    record Event(String id, int sequence) {
    }

    record DedupReport(List<String> uniqueIds, long operations) {
    }

    record QueryReport(List<Integer> positions, int sortCalls) {
    }
}
