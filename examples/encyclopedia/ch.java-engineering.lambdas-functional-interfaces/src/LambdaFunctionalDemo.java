import java.util.ArrayList;
import java.util.List;
import java.util.Objects;
import java.util.function.Consumer;
import java.util.function.Function;
import java.util.function.Predicate;
import java.util.function.Supplier;

public final class LambdaFunctionalDemo {
    private LambdaFunctionalDemo() {
    }

    public record WorkOrder(String id, int priority, boolean open) {
        public WorkOrder {
            Objects.requireNonNull(id, "id");
        }
    }

    @FunctionalInterface
    interface DispatchRule {
        boolean accepts(WorkOrder order);

        default DispatchRule and(DispatchRule other) {
            Objects.requireNonNull(other, "other");
            return order -> accepts(order) && other.accepts(order);
        }
    }

    @FunctionalInterface
    interface WorkOrderFactory {
        WorkOrder create(String id, int priority, boolean open);
    }

    static boolean isOpen(WorkOrder order) {
        return Objects.requireNonNull(order, "order").open();
    }

    static String priorityLabel(WorkOrder order) {
        Objects.requireNonNull(order, "order");
        return "P" + order.priority() + ":" + order.id();
    }

    public static void main(String[] args) {
        List<WorkOrder> orders = List.of(
                new WorkOrder("WO-101", 4, true),
                new WorkOrder("WO-102", 2, true),
                new WorkOrder("WO-103", 3, true),
                new WorkOrder("WO-104", 5, false));

        int threshold = 3;
        Predicate<WorkOrder> urgent = order -> order.priority() >= threshold;
        Predicate<WorkOrder> dispatchablePredicate = urgent.and(WorkOrder::open);
        List<String> acceptedIds = new ArrayList<>();
        for (WorkOrder order : orders) {
            if (dispatchablePredicate.test(order)) {
                acceptedIds.add(order.id());
            }
        }

        Function<WorkOrder, String> lambdaLabel = order -> priorityLabel(order);
        Function<WorkOrder, String> referenceLabel = LambdaFunctionalDemo::priorityLabel;
        List<String> notifications = new ArrayList<>();
        Consumer<String> append = notifications::add;
        Consumer<WorkOrder> notify = order -> append.accept("notify:" + order.id());
        notify.accept(orders.getFirst());

        WorkOrderFactory constructor = WorkOrder::new;
        Supplier<WorkOrder> nextOrder = () -> constructor.create("WO-201", 1, true);

        DispatchRule open = LambdaFunctionalDemo::isOpen;
        DispatchRule highPriority = order -> order.priority() >= threshold;
        DispatchRule dispatchable = open.and(highPriority);

        System.out.println("sam.annotation=" + DispatchRule.class.isAnnotationPresent(FunctionalInterface.class));
        System.out.println("predicate.ids=" + String.join(",", acceptedIds));
        System.out.println("function.label=" + lambdaLabel.apply(orders.getFirst()));
        System.out.println("consumer.messages=" + String.join(",", notifications));
        System.out.println("methodReference.same="
                + lambdaLabel.apply(orders.getFirst()).equals(referenceLabel.apply(orders.getFirst())));
        System.out.println("capture.threshold=" + threshold);
        System.out.println("constructor.id=" + nextOrder.get().id());
        System.out.println("composition.closedRejected=" + !dispatchable.accepts(orders.getLast()));
    }
}
