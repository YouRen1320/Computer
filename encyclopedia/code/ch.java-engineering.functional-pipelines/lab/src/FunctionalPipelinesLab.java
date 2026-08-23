import java.util.ArrayList;
import java.util.Collections;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.Optional;
import java.util.OptionalInt;
import java.util.function.Supplier;
import java.util.stream.Collectors;

public final class FunctionalPipelinesLab {
    private FunctionalPipelinesLab() {
    }

    public record WorkOrder(String id, String category, int priority, int minutes, boolean open) {
        public WorkOrder {
            Objects.requireNonNull(id, "id");
            Objects.requireNonNull(category, "category");
            if (priority < 1 || priority > 5) {
                throw new IllegalArgumentException("priority must be 1..5");
            }
            if (minutes < 0) {
                throw new IllegalArgumentException("minutes must be non-negative");
            }
        }
    }

    public record Summary(List<String> openIds, Map<String, Integer> minutesByCategory,
            int totalMinutes, OptionalInt maximumPriority) {
        public Summary {
            openIds = List.copyOf(openIds);
            minutesByCategory = Collections.unmodifiableMap(new LinkedHashMap<>(minutesByCategory));
            Objects.requireNonNull(maximumPriority, "maximumPriority");
        }
    }

    public static Summary summarizeWithLoop(List<WorkOrder> orders) {
        Objects.requireNonNull(orders, "orders");
        List<String> ids = new ArrayList<>();
        Map<String, Integer> groups = new LinkedHashMap<>();
        int total = 0;
        int maximum = Integer.MIN_VALUE;
        for (WorkOrder order : orders) {
            Objects.requireNonNull(order, "order");
            if (!order.open()) {
                continue;
            }
            ids.add(order.id());
            groups.merge(order.category(), order.minutes(), Integer::sum);
            total += order.minutes();
            maximum = Math.max(maximum, order.priority());
        }
        OptionalInt optionalMaximum = ids.isEmpty() ? OptionalInt.empty() : OptionalInt.of(maximum);
        return new Summary(ids, groups, total, optionalMaximum);
    }

    public static Summary summarizeWithStream(List<WorkOrder> orders) {
        Objects.requireNonNull(orders, "orders");
        List<WorkOrder> open = orders.stream()
                .map(order -> Objects.requireNonNull(order, "order"))
                .filter(WorkOrder::open)
                .toList();
        List<String> ids = open.stream().map(WorkOrder::id).toList();
        Map<String, Integer> groups = open.stream().collect(Collectors.groupingBy(
                WorkOrder::category,
                LinkedHashMap::new,
                Collectors.summingInt(WorkOrder::minutes)));
        int total = open.stream().mapToInt(WorkOrder::minutes).sum();
        OptionalInt maximum = open.stream().mapToInt(WorkOrder::priority).max();
        return new Summary(ids, groups, total, maximum);
    }

    public static Optional<WorkOrder> highestPriority(List<WorkOrder> orders) {
        Objects.requireNonNull(orders, "orders");
        return orders.stream().filter(WorkOrder::open)
                .max((left, right) -> Integer.compare(left.priority(), right.priority()));
    }

    public static String valueOrFallback(Optional<String> value, Supplier<String> fallback) {
        Objects.requireNonNull(value, "value");
        Objects.requireNonNull(fallback, "fallback");
        return value.orElseGet(fallback);
    }
}
