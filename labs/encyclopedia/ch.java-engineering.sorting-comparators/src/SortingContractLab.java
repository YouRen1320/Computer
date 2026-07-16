import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;

final class SortingContractLab {
    private SortingContractLab() {
    }

    static final Comparator<WorkOrder> DISPATCH_ORDER = Comparator
            .comparingInt(WorkOrder::priority).reversed()
            .thenComparing(WorkOrder::createdAt)
            .thenComparing(WorkOrder::id);

    static List<WorkOrder> sortedCopy(List<WorkOrder> source, Comparator<WorkOrder> comparator) {
        List<WorkOrder> result = new ArrayList<>(source);
        result.sort(comparator);
        return List.copyOf(result);
    }

    static WorkOrder order(String id, int priority, String createdAt, String dueAt) {
        return new WorkOrder(
                id,
                priority,
                LocalDateTime.parse(createdAt),
                dueAt == null ? null : LocalDateTime.parse(dueAt));
    }

    record WorkOrder(String id, int priority, LocalDateTime createdAt, LocalDateTime dueAt) {
    }

    record StableItem(String id, int priority) {
    }

    record DeviceId(String value) implements Comparable<DeviceId> {
        @Override
        public int compareTo(DeviceId other) {
            return value.compareTo(other.value);
        }
    }
}
