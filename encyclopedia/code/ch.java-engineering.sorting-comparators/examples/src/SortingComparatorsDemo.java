import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;
import java.util.stream.Collectors;

public final class SortingComparatorsDemo {
    private SortingComparatorsDemo() {
    }

    public static void main(String[] args) {
        List<DeviceId> deviceIds = new ArrayList<>(List.of(
                new DeviceId("PUMP-01"), new DeviceId("FAN-02")));
        deviceIds.sort(Comparator.naturalOrder());
        System.out.println("natural.deviceIds=" + deviceIds.stream()
                .map(DeviceId::value).collect(Collectors.joining(",")));

        List<WorkOrder> source = List.of(
                order("WO-103", 3, "2026-07-16T09:10", null),
                order("WO-101", 3, "2026-07-16T09:00", "2026-07-16T13:00"),
                order("WO-104", 2, "2026-07-16T08:00", "2026-07-16T11:00"),
                order("WO-102", 3, "2026-07-16T09:00", "2026-07-16T12:00"));
        Comparator<WorkOrder> dispatchOrder = Comparator
                .comparingInt(WorkOrder::priority).reversed()
                .thenComparing(WorkOrder::createdAt)
                .thenComparing(WorkOrder::id);
        List<WorkOrder> sorted = new ArrayList<>(source);
        sorted.sort(dispatchOrder);
        System.out.println("dispatch.order=" + ids(sorted));
        System.out.println("dispatch.first.priority=" + sorted.getFirst().priority());
        System.out.println("dispatch.first.createdAt=" + sorted.getFirst().createdAt());

        List<StableItem> stable = new ArrayList<>(List.of(
                new StableItem("A", 2), new StableItem("B", 1),
                new StableItem("C", 2), new StableItem("D", 1)));
        stable.sort(Comparator.comparingInt(StableItem::priority).reversed());
        System.out.println("stable.priorityOnly=" + stable.stream()
                .map(StableItem::id).collect(Collectors.joining(",")));

        List<WorkOrder> due = new ArrayList<>(List.of(
                order("WO-202", 1, "2026-07-16T08:00", null),
                order("WO-203", 1, "2026-07-16T08:00", "2026-07-16T10:00"),
                order("WO-201", 1, "2026-07-16T08:00", "2026-07-16T09:00")));
        Comparator<WorkOrder> byDueAt = Comparator.comparing(
                WorkOrder::dueAt,
                Comparator.nullsLast(Comparator.naturalOrder()));
        due.sort(byDueAt.thenComparing(WorkOrder::id));
        System.out.println("nullsLast.dueAt=" + ids(due));
        System.out.println("source.unchanged=" + ids(source));

        int forward = Integer.signum(dispatchOrder.compare(source.get(0), source.get(1)));
        int reverse = Integer.signum(dispatchOrder.compare(source.get(1), source.get(0)));
        System.out.println("contract.signReverse=" + (forward == -reverse));
    }

    private static WorkOrder order(String id, int priority, String createdAt, String dueAt) {
        return new WorkOrder(
                id,
                priority,
                LocalDateTime.parse(createdAt),
                dueAt == null ? null : LocalDateTime.parse(dueAt));
    }

    private static String ids(List<WorkOrder> orders) {
        return orders.stream().map(WorkOrder::id).collect(Collectors.joining(","));
    }

    record DeviceId(String value) implements Comparable<DeviceId> {
        @Override
        public int compareTo(DeviceId other) {
            return value.compareTo(other.value);
        }
    }

    record WorkOrder(String id, int priority, LocalDateTime createdAt, LocalDateTime dueAt) {
    }

    record StableItem(String id, int priority) {
    }
}
