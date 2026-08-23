import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.OptionalInt;
import java.util.concurrent.atomic.AtomicInteger;
import java.util.function.Function;
import java.util.stream.Collectors;
import java.util.stream.Stream;

public final class FunctionalPipelinesDemo {
    private FunctionalPipelinesDemo() {
    }

    record WorkOrder(String id, String category, int priority, int minutes, boolean open) {
        WorkOrder {
            Objects.requireNonNull(id, "id");
            Objects.requireNonNull(category, "category");
        }
    }

    public static void main(String[] args) {
        List<WorkOrder> orders = List.of(
                new WorkOrder("WO-101", "MECHANICAL", 4, 30, true),
                new WorkOrder("WO-102", "ELECTRICAL", 2, 45, false),
                new WorkOrder("WO-103", "ELECTRICAL", 5, 20, true),
                new WorkOrder("WO-104", "MECHANICAL", 3, 25, true),
                new WorkOrder("WO-105", "NETWORK", 3, 40, true));

        AtomicInteger visits = new AtomicInteger();
        Stream<WorkOrder> lazy = orders.stream().filter(order -> {
            visits.incrementAndGet();
            return order.open();
        });
        System.out.println("lazy.before=" + visits.get());
        List<WorkOrder> openOrders = lazy.toList();
        System.out.println("lazy.after=" + visits.get());

        List<String> ids = openOrders.stream().map(WorkOrder::id).toList();
        Map<String, Integer> minutesByCategory = openOrders.stream().collect(Collectors.groupingBy(
                WorkOrder::category,
                LinkedHashMap::new,
                Collectors.summingInt(WorkOrder::minutes)));
        int total = openOrders.stream().mapToInt(WorkOrder::minutes).sum();
        OptionalInt maximum = openOrders.stream().mapToInt(WorkOrder::priority).max();
        int emptyMaximum = List.<WorkOrder>of().stream().mapToInt(WorkOrder::priority).max().orElse(0);

        String groups = minutesByCategory.entrySet().stream()
                .map(entry -> entry.getKey() + ":" + entry.getValue())
                .collect(Collectors.joining(","));
        System.out.println("open.ids=" + String.join(",", ids));
        System.out.println("group.minutes=" + groups);
        System.out.println("reduce.total=" + total);
        System.out.println("optional.max=" + maximum.orElseThrow());
        System.out.println("optional.emptyFallback=" + emptyMaximum);
        System.out.println("source.unchanged=" + (orders.size() == 5));
    }
}
