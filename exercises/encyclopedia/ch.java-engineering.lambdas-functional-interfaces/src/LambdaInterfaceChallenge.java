import java.util.ArrayList;
import java.util.List;
import java.util.Objects;
import java.util.function.Consumer;
import java.util.function.Function;
import java.util.function.Predicate;

public final class LambdaInterfaceChallenge {
    private LambdaInterfaceChallenge() {
    }

    record WorkOrder(String id, int priority, boolean open) {
        WorkOrder {
            Objects.requireNonNull(id, "id");
        }
    }

    static Predicate<WorkOrder> dispatchable(int threshold) {
        // TODO 1: validate threshold and return an open-and-urgent Predicate.
        return order -> false;
    }

    static String priorityLabel(WorkOrder order) {
        // TODO 2: reject null and return P{priority}:{id}.
        return "TODO";
    }

    static Consumer<WorkOrder> notifier(List<String> messages) {
        // TODO 3: reject nulls and append exactly one notify:{id} entry per call.
        return order -> { };
    }

    public static void main(String[] args) {
        WorkOrder urgent = new WorkOrder("WO-101", 4, true);
        Predicate<WorkOrder> rule = dispatchable(3);
        Function<WorkOrder, String> lambda = order -> priorityLabel(order);
        Function<WorkOrder, String> reference = LambdaInterfaceChallenge::priorityLabel;
        List<String> messages = new ArrayList<>();
        notifier(messages).accept(urgent);

        // TODO 4: keep this oracle green without weakening its expected values.
        boolean valid = rule.test(urgent)
                && "P4:WO-101".equals(lambda.apply(urgent))
                && lambda.apply(urgent).equals(reference.apply(urgent))
                && messages.equals(List.of("notify:WO-101"));
        if (!valid) {
            throw new IllegalStateException("BEHAVIOR_CONTRACT complete TODO 1..4");
        }
        System.out.println("CHALLENGE PASS assertions=4");
    }
}
