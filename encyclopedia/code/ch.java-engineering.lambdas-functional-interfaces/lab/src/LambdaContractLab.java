import java.util.ArrayList;
import java.util.List;
import java.util.Objects;
import java.util.function.Consumer;
import java.util.function.Function;
import java.util.function.Predicate;
import java.util.function.Supplier;

public final class LambdaContractLab {
    private LambdaContractLab() {
    }

    public record WorkOrder(String id, int priority, boolean open) {
        public WorkOrder {
            Objects.requireNonNull(id, "id");
            if (priority < 1 || priority > 5) {
                throw new IllegalArgumentException("priority must be 1..5");
            }
        }
    }

    @FunctionalInterface
    public interface DispatchRule {
        boolean accepts(WorkOrder order);

        default DispatchRule and(DispatchRule other) {
            Objects.requireNonNull(other, "other");
            return order -> accepts(order) && other.accepts(order);
        }
    }

    @FunctionalInterface
    public interface WorkOrderFactory {
        WorkOrder create(String id, int priority, boolean open);
    }

    public static Predicate<WorkOrder> atLeast(int threshold) {
        if (threshold < 1 || threshold > 5) {
            throw new IllegalArgumentException("threshold must be 1..5");
        }
        return order -> Objects.requireNonNull(order, "order").priority() >= threshold;
    }

    public static boolean isOpen(WorkOrder order) {
        return Objects.requireNonNull(order, "order").open();
    }

    public static String priorityLabel(WorkOrder order) {
        Objects.requireNonNull(order, "order");
        return "P" + order.priority() + ":" + order.id();
    }

    public static Consumer<WorkOrder> notifier(List<String> messages) {
        Objects.requireNonNull(messages, "messages");
        return order -> messages.add("notify:" + Objects.requireNonNull(order, "order").id());
    }

    public static Supplier<WorkOrder> fixedOrder(String id) {
        Objects.requireNonNull(id, "id");
        return () -> new WorkOrder(id, 1, true);
    }

    public static List<String> acceptedIds(List<WorkOrder> orders, Predicate<WorkOrder> rule) {
        Objects.requireNonNull(orders, "orders");
        Objects.requireNonNull(rule, "rule");
        List<String> result = new ArrayList<>();
        for (WorkOrder order : orders) {
            if (rule.test(order)) {
                result.add(order.id());
            }
        }
        return List.copyOf(result);
    }

    public static List<String> labels(List<WorkOrder> orders, Function<WorkOrder, String> mapper) {
        Objects.requireNonNull(orders, "orders");
        Objects.requireNonNull(mapper, "mapper");
        List<String> result = new ArrayList<>();
        for (WorkOrder order : orders) {
            result.add(mapper.apply(order));
        }
        return List.copyOf(result);
    }
}
