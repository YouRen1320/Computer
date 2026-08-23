import java.util.ArrayList;
import java.util.List;
import java.util.Objects;
import java.util.function.Consumer;
import java.util.function.Function;
import java.util.function.Predicate;

public final class LambdaInterfaceChallenge {
    private static int assertions;

    private LambdaInterfaceChallenge() {
    }

    record WorkOrder(String id, int priority, boolean open) {
        WorkOrder {
            Objects.requireNonNull(id, "id");
        }
    }

    static void check(boolean condition, String name) {
        assertions++;
        if (!condition) {
            throw new AssertionError(name);
        }
    }

    static Predicate<WorkOrder> dispatchable(int threshold) {
        if (threshold < 1 || threshold > 5) {
            throw new IllegalArgumentException("threshold must be 1..5");
        }
        return order -> {
            Objects.requireNonNull(order, "order");
            return order.open() && order.priority() >= threshold;
        };
    }

    static String priorityLabel(WorkOrder order) {
        Objects.requireNonNull(order, "order");
        return "P" + order.priority() + ":" + order.id();
    }

    static Consumer<WorkOrder> notifier(List<String> messages) {
        Objects.requireNonNull(messages, "messages");
        return order -> messages.add("notify:" + Objects.requireNonNull(order, "order").id());
    }

    public static void main(String[] args) {
        WorkOrder below = new WorkOrder("WO-100", 2, true);
        WorkOrder equal = new WorkOrder("WO-101", 3, true);
        WorkOrder above = new WorkOrder("WO-102", 4, true);
        WorkOrder closed = new WorkOrder("WO-103", 5, false);
        Predicate<WorkOrder> rule = dispatchable(3);
        check(!rule.test(below), "below");
        check(rule.test(equal), "equal");
        check(rule.test(above), "above");
        check(!rule.test(closed), "closed");

        Function<WorkOrder, String> lambda = order -> priorityLabel(order);
        Function<WorkOrder, String> reference = LambdaInterfaceChallenge::priorityLabel;
        check("P4:WO-102".equals(lambda.apply(above)), "label");
        check(lambda.apply(above).equals(reference.apply(above)), "reference");

        List<String> messages = new ArrayList<>();
        Consumer<WorkOrder> notify = notifier(messages);
        notify.accept(equal);
        notify.accept(above);
        check(messages.equals(List.of("notify:WO-101", "notify:WO-102")), "notifications");
        check(messages.size() == 2, "exact count");

        boolean invalidRejected = false;
        try {
            dispatchable(0);
        } catch (IllegalArgumentException expected) {
            invalidRejected = true;
        }
        check(invalidRejected, "invalid threshold");

        boolean nullRuleRejected = false;
        try {
            rule.test(null);
        } catch (NullPointerException expected) {
            nullRuleRejected = true;
        }
        check(nullRuleRejected, "null rule input");

        boolean nullLabelRejected = false;
        try {
            priorityLabel(null);
        } catch (NullPointerException expected) {
            nullLabelRejected = true;
        }
        check(nullLabelRejected, "null label input");
        check(equal.priority() == 3, "source unchanged");

        System.out.println("PRIVATE SOLUTION PASS assertions=" + assertions);
    }
}
