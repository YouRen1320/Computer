import java.util.Comparator;
import java.util.Set;
import java.util.TreeSet;

public final class TreeSetEqualityFailure {
    private TreeSetEqualityFailure() {
    }

    public static void main(String[] args) {
        Set<WorkOrder> orders = new TreeSet<>(Comparator.comparingInt(WorkOrder::priority));
        orders.add(new WorkOrder("WO-1", 3));
        orders.add(new WorkOrder("WO-2", 3));
        if (orders.size() == 1) {
            throw new IllegalStateException("COMPARATOR_COLLISION");
        }
    }

    private record WorkOrder(String id, int priority) {
    }
}
