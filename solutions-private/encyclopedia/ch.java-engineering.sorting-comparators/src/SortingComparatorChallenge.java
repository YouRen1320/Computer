import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;

public final class SortingComparatorChallenge {
    private SortingComparatorChallenge() {
    }

    public static void main(String[] args) {
        int assertions = 0;
        List<WorkOrder> source = List.of(
                order("WO-103", 3, "2026-07-16T09:30", null),
                order("WO-101", 3, "2026-07-16T09:00", "2026-07-16T11:00"),
                order("WO-104", 2, "2026-07-16T08:00", "2026-07-16T10:00"),
                order("WO-102", 3, "2026-07-16T09:00", "2026-07-16T12:00"));
        List<WorkOrder> sorted = sortedCopy(source, dispatchOrder());
        check(ids(sorted).equals(List.of("WO-101", "WO-102", "WO-103", "WO-104")), "dispatch order"); assertions++;
        check(ids(source).equals(List.of("WO-103", "WO-101", "WO-104", "WO-102")), "source unchanged"); assertions++;
        check(sorted.getFirst().priority() == 3, "highest priority first"); assertions++;
        check(sorted.get(0).id().equals("WO-101") && sorted.get(1).id().equals("WO-102"), "id tie breaker"); assertions++;

        check(compareSeverity(Integer.MIN_VALUE, 1) < 0, "safe extreme compare"); assertions++;
        check(compareSeverity(1, Integer.MIN_VALUE) > 0, "safe reverse compare"); assertions++;
        check(compareSeverity(7, 7) == 0, "safe self compare"); assertions++;

        List<WorkOrder> due = sortedCopy(source, dueAtOrder());
        check(ids(due).equals(List.of("WO-104", "WO-101", "WO-102", "WO-103")), "due order"); assertions++;
        check(due.getLast().dueAt() == null, "null due last"); assertions++;

        List<StableItem> stable = new ArrayList<>(List.of(
                new StableItem("C", 2), new StableItem("A", 2),
                new StableItem("B", 1), new StableItem("D", 1)));
        Comparator<StableItem> primaryOnly = stablePriorityOrder();
        stable.sort(primaryOnly);
        check(stable.stream().map(StableItem::id).toList()
                .equals(List.of("C", "A", "B", "D")), "stable input order"); assertions++;
        check(primaryOnly.compare(stable.get(0), stable.get(1)) == 0, "primary equality"); assertions++;
        expectUnsupported(() -> sorted.add(source.getFirst())); assertions++;
        int forward = Integer.signum(dispatchOrder().compare(source.get(0), source.get(1)));
        int reverse = Integer.signum(dispatchOrder().compare(source.get(1), source.get(0)));
        check(forward == -reverse, "sign symmetry"); assertions++;
        check(sortedCopy(List.of(), dispatchOrder()).isEmpty(), "empty sort"); assertions++;

        System.out.println("exercise.assertions=" + assertions + " passed");
    }

    static Comparator<WorkOrder> dispatchOrder() {
        return Comparator.comparingInt(WorkOrder::priority).reversed()
                .thenComparing(WorkOrder::createdAt)
                .thenComparing(WorkOrder::id);
    }

    static int compareSeverity(int left, int right) {
        return Integer.compare(left, right);
    }

    static Comparator<WorkOrder> dueAtOrder() {
        return Comparator.comparing(
                WorkOrder::dueAt,
                Comparator.nullsLast(Comparator.naturalOrder()));
    }

    static Comparator<StableItem> stablePriorityOrder() {
        return Comparator.comparingInt(StableItem::priority).reversed();
    }

    static List<WorkOrder> sortedCopy(List<WorkOrder> source, Comparator<WorkOrder> comparator) {
        List<WorkOrder> result = new ArrayList<>(source);
        result.sort(comparator);
        return List.copyOf(result);
    }

    static WorkOrder order(String id, int priority, String createdAt, String dueAt) {
        return new WorkOrder(id, priority, LocalDateTime.parse(createdAt),
                dueAt == null ? null : LocalDateTime.parse(dueAt));
    }

    static List<String> ids(List<WorkOrder> orders) {
        return orders.stream().map(WorkOrder::id).toList();
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

    record WorkOrder(String id, int priority, LocalDateTime createdAt, LocalDateTime dueAt) {
    }

    record StableItem(String id, int priority) {
    }
}
