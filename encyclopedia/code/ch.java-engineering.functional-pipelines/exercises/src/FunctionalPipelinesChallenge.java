import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.Optional;
import java.util.OptionalInt;
import java.util.function.Supplier;

public final class FunctionalPipelinesChallenge {
    private FunctionalPipelinesChallenge() {
    }

    record WorkOrder(String id, String category, int priority, int minutes, boolean open) {
        WorkOrder {
            Objects.requireNonNull(id, "id");
            Objects.requireNonNull(category, "category");
        }
    }

    static List<String> openIds(List<WorkOrder> orders) {
        // TODO 1: filter open orders, map IDs, and return an unmodifiable result.
        return List.of();
    }

    static Map<String, Integer> minutesByCategory(List<WorkOrder> orders) {
        // TODO 2: group open orders with LinkedHashMap encounter order.
        return new LinkedHashMap<>();
    }

    static int totalMinutes(List<WorkOrder> orders) {
        // TODO 3: sum minutes for open orders only.
        return -1;
    }

    static OptionalInt highestPriority(List<WorkOrder> orders) {
        // TODO 4: return empty for no open orders.
        return OptionalInt.empty();
    }

    static String valueOrFallback(Optional<String> value, Supplier<String> fallback) {
        // TODO 5: evaluate fallback lazily.
        return "TODO";
    }

    public static void main(String[] args) {
        List<WorkOrder> orders = List.of(
                new WorkOrder("WO-101", "MECHANICAL", 4, 30, true),
                new WorkOrder("WO-102", "ELECTRICAL", 2, 45, false),
                new WorkOrder("WO-103", "ELECTRICAL", 5, 20, true));
        Map<String, Integer> expectedGroups = new LinkedHashMap<>();
        expectedGroups.put("MECHANICAL", 30);
        expectedGroups.put("ELECTRICAL", 20);
        boolean valid = openIds(orders).equals(List.of("WO-101", "WO-103"))
                && minutesByCategory(orders).equals(expectedGroups)
                && totalMinutes(orders) == 50
                && highestPriority(orders).orElseThrow() == 5
                && valueOrFallback(Optional.empty(), () -> "fallback").equals("fallback");
        if (!valid) {
            throw new IllegalStateException("PIPELINE_CONTRACT complete TODO 1..5");
        }
        System.out.println("CHALLENGE PASS assertions=5");
    }
}
