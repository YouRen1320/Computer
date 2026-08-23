import java.util.List;

public final class LockOrderCycleFailure {
    private LockOrderCycleFailure() {
    }

    record Edge(String from, String to) {
    }

    public static void main(String[] args) {
        List<Edge> orders = List.of(new Edge("device", "workOrder"), new Edge("workOrder", "device"));
        for (Edge left : orders) {
            for (Edge right : orders) {
                if (left.from().equals(right.to()) && left.to().equals(right.from())) {
                    throw new IllegalStateException("LOCK_ORDER_CYCLE "
                            + left.from() + "->" + left.to() + "->" + right.to());
                }
            }
        }
    }
}
