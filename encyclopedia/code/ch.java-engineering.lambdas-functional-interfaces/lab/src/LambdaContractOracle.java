import java.util.ArrayList;
import java.util.List;
import java.util.Objects;
import java.util.concurrent.atomic.AtomicInteger;
import java.util.function.Consumer;
import java.util.function.Function;
import java.util.function.Predicate;
import java.util.function.Supplier;

public final class LambdaContractOracle {
    private static int assertions;

    private LambdaContractOracle() {
    }

    private static void check(boolean condition, String name) {
        assertions++;
        if (!condition) {
            throw new AssertionError(name);
        }
    }

    private static void equal(Object expected, Object actual, String name) {
        check(Objects.equals(expected, actual), name + " expected=" + expected + " actual=" + actual);
    }

    public static void main(String[] args) {
        List<LambdaContractLab.WorkOrder> orders = List.of(
                new LambdaContractLab.WorkOrder("WO-101", 4, true),
                new LambdaContractLab.WorkOrder("WO-102", 3, true),
                new LambdaContractLab.WorkOrder("WO-103", 2, true),
                new LambdaContractLab.WorkOrder("WO-104", 5, false));

        int threshold = 3;
        Predicate<LambdaContractLab.WorkOrder> urgent = LambdaContractLab.atLeast(threshold);
        check(!urgent.test(orders.get(2)), "below threshold");
        check(urgent.test(orders.get(1)), "equal threshold");
        check(urgent.test(orders.get(0)), "above threshold");
        equal(List.of("WO-101", "WO-102", "WO-104"),
                LambdaContractLab.acceptedIds(orders, urgent), "predicate IDs");

        LambdaContractLab.DispatchRule open = LambdaContractLab::isOpen;
        AtomicInteger rightCalls = new AtomicInteger();
        LambdaContractLab.DispatchRule countedUrgent = order -> {
            rightCalls.incrementAndGet();
            return order.priority() >= threshold;
        };
        LambdaContractLab.DispatchRule dispatchable = open.and(countedUrgent);
        check(dispatchable.accepts(orders.get(0)), "open urgent accepted");
        check(!dispatchable.accepts(orders.get(3)), "closed rejected");
        equal(1, rightCalls.get(), "and short-circuits");

        Function<LambdaContractLab.WorkOrder, String> lambda = order -> LambdaContractLab.priorityLabel(order);
        Function<LambdaContractLab.WorkOrder, String> staticReference = LambdaContractLab::priorityLabel;
        equal("P4:WO-101", lambda.apply(orders.get(0)), "lambda label");
        equal(lambda.apply(orders.get(0)), staticReference.apply(orders.get(0)), "static reference");
        equal(List.of("P4:WO-101", "P3:WO-102", "P2:WO-103"),
                LambdaContractLab.labels(orders.subList(0, 3), staticReference), "all labels");

        Function<LambdaContractLab.WorkOrder, String> unboundReference = LambdaContractLab.WorkOrder::id;
        equal("WO-102", unboundReference.apply(orders.get(1)), "unbound reference");
        List<String> messages = new ArrayList<>();
        Consumer<LambdaContractLab.WorkOrder> notify = LambdaContractLab.notifier(messages);
        notify.accept(orders.get(0));
        notify.accept(orders.get(1));
        equal(List.of("notify:WO-101", "notify:WO-102"), messages, "bound write target");

        LambdaContractLab.WorkOrderFactory constructorReference = LambdaContractLab.WorkOrder::new;
        equal("WO-201", constructorReference.create("WO-201", 1, true).id(), "constructor reference");
        Supplier<LambdaContractLab.WorkOrder> supplier = LambdaContractLab.fixedOrder("WO-202");
        check(supplier.get() != supplier.get(), "supplier creates fresh values");
        equal(3, threshold, "captured threshold remains stable");

        boolean nullRejected = false;
        try {
            urgent.test(null);
        } catch (NullPointerException expected) {
            nullRejected = true;
        }
        check(nullRejected, "predicate null contract");

        boolean invalidThresholdRejected = false;
        try {
            LambdaContractLab.atLeast(0);
        } catch (IllegalArgumentException expected) {
            invalidThresholdRejected = true;
        }
        check(invalidThresholdRejected, "threshold validation");

        Predicate<LambdaContractLab.WorkOrder> composed = urgent.and(LambdaContractLab::isOpen);
        check(composed.test(orders.get(1)), "predicate composition true");
        check(!composed.test(orders.get(3)), "predicate composition false");
        equal(4, orders.size(), "source unchanged");

        System.out.println("report.rules=" + String.join(",",
                LambdaContractLab.acceptedIds(orders, composed)));
        System.out.println("report.labels=" + String.join(",",
                LambdaContractLab.labels(orders.subList(0, 3), staticReference)));
        System.out.println("report.notifications=" + String.join(",", messages));
        System.out.println("report.references=static:true,bound:true,unbound:true,constructor:true");
        System.out.println("report.capture=threshold:3,below:false,equal:true,above:true");
        System.out.println("assertions=" + assertions + " passed");
    }
}
