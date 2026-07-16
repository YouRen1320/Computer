import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.Optional;
import java.util.OptionalInt;
import java.util.concurrent.atomic.AtomicInteger;
import java.util.function.Supplier;
import java.util.stream.Collectors;

public final class FunctionalPipelinesChallenge {
    private static int assertions;

    private FunctionalPipelinesChallenge() {
    }

    record WorkOrder(String id, String category, int priority, int minutes, boolean open) {
        WorkOrder {
            Objects.requireNonNull(id, "id");
            Objects.requireNonNull(category, "category");
        }
    }

    static void check(boolean condition, String name) {
        assertions++;
        if (!condition) {
            throw new AssertionError(name);
        }
    }

    static List<String> openIds(List<WorkOrder> orders) {
        Objects.requireNonNull(orders, "orders");
        return orders.stream().filter(WorkOrder::open).map(WorkOrder::id).toList();
    }

    static Map<String, Integer> minutesByCategory(List<WorkOrder> orders) {
        Objects.requireNonNull(orders, "orders");
        return orders.stream().filter(WorkOrder::open).collect(Collectors.groupingBy(
                WorkOrder::category,
                LinkedHashMap::new,
                Collectors.summingInt(WorkOrder::minutes)));
    }

    static int totalMinutes(List<WorkOrder> orders) {
        Objects.requireNonNull(orders, "orders");
        return orders.stream().filter(WorkOrder::open).mapToInt(WorkOrder::minutes).sum();
    }

    static OptionalInt highestPriority(List<WorkOrder> orders) {
        Objects.requireNonNull(orders, "orders");
        return orders.stream().filter(WorkOrder::open).mapToInt(WorkOrder::priority).max();
    }

    static String valueOrFallback(Optional<String> value, Supplier<String> fallback) {
        Objects.requireNonNull(value, "value");
        Objects.requireNonNull(fallback, "fallback");
        return value.orElseGet(fallback);
    }

    public static void main(String[] args) {
        List<WorkOrder> empty = List.of();
        check(openIds(empty).isEmpty(), "empty IDs");
        check(minutesByCategory(empty).isEmpty(), "empty groups");
        check(totalMinutes(empty) == 0, "empty total");
        check(highestPriority(empty).isEmpty(), "empty maximum");

        List<WorkOrder> orders = new ArrayList<>(List.of(
                new WorkOrder("WO-101", "MECHANICAL", 4, 30, true),
                new WorkOrder("WO-102", "ELECTRICAL", 2, 45, false),
                new WorkOrder("WO-103", "ELECTRICAL", 5, 20, true),
                new WorkOrder("WO-104", "MECHANICAL", 3, 25, true)));
        List<WorkOrder> snapshot = List.copyOf(orders);
        check(openIds(orders).equals(List.of("WO-101", "WO-103", "WO-104")), "open IDs");
        Map<String, Integer> expectedGroups = new LinkedHashMap<>();
        expectedGroups.put("MECHANICAL", 55);
        expectedGroups.put("ELECTRICAL", 20);
        check(minutesByCategory(orders).equals(expectedGroups), "groups");
        check(List.copyOf(minutesByCategory(orders).keySet()).equals(List.of("MECHANICAL", "ELECTRICAL")),
                "group order");
        check(totalMinutes(orders) == 75, "total");
        check(highestPriority(orders).orElseThrow() == 5, "maximum");
        check(orders.equals(snapshot), "source unchanged");

        AtomicInteger calls = new AtomicInteger();
        String present = valueOrFallback(Optional.of("known"), () -> {
            calls.incrementAndGet();
            return "fallback";
        });
        check(present.equals("known"), "present value");
        check(calls.get() == 0, "present lazy");
        String missing = valueOrFallback(Optional.empty(), () -> {
            calls.incrementAndGet();
            return "fallback";
        });
        check(missing.equals("fallback"), "empty fallback");
        check(calls.get() == 1, "empty exactly once");

        System.out.println("PRIVATE SOLUTION PASS assertions=" + assertions);
    }
}
