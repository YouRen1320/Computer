import java.util.ArrayDeque;
import java.util.ArrayList;
import java.util.List;
import java.util.Queue;

public final class SequentialCollectionsOracle {
    private SequentialCollectionsOracle() {
    }

    public static void main(String[] args) {
        int assertions = 0;
        List<String> input = List.of("WO-201", "WO-202", "WO-201");
        check(input.size() == 3, "list keeps duplicates"); assertions++;
        check("WO-201".equals(input.getFirst()), "list first"); assertions++;
        check("WO-201".equals(input.getLast()), "list last"); assertions++;

        List<String> fifo = SequentialCollectionsLab.dispatchInFifoOrder(
                List.of("WO-201", "WO-202", "WO-203"));
        check(fifo.equals(List.of("WO-201", "WO-202", "WO-203")), "fifo order"); assertions++;
        check(fifo.size() == 3, "fifo size"); assertions++;

        List<String> lifo = SequentialCollectionsLab.undoInLifoOrder(
                List.of("assign:WO-201", "assign:WO-202", "assign:WO-203"));
        check(lifo.equals(List.of("assign:WO-203", "assign:WO-202", "assign:WO-201")), "lifo order"); assertions++;
        check(lifo.getFirst().endsWith("203"), "latest action first"); assertions++;

        Queue<String> empty = new ArrayDeque<>();
        check(empty.poll() == null, "empty poll"); assertions++;
        check(empty.peek() == null, "empty peek"); assertions++;

        List<String> timeline = new ArrayList<>(List.of("RECEIVED", "VALIDATED"));
        List<String> view = SequentialCollectionsLab.readOnlyView(timeline);
        List<String> snapshot = SequentialCollectionsLab.snapshot(timeline);
        timeline.add("ASSIGNED");
        check(view.size() == 3, "view observes source"); assertions++;
        check(snapshot.size() == 2, "snapshot stable"); assertions++;
        check("VALIDATED".equals(snapshot.getLast()), "snapshot content"); assertions++;
        expectUnsupported(() -> view.add("CLOSED")); assertions++;
        expectUnsupported(() -> snapshot.add("CLOSED")); assertions++;

        List<SequentialCollectionsLab.WorkOrder> orders = new ArrayList<>(List.of(
                new SequentialCollectionsLab.WorkOrder("KEEP-1", false),
                new SequentialCollectionsLab.WorkOrder("CANCEL-1", true),
                new SequentialCollectionsLab.WorkOrder("CANCEL-2", true),
                new SequentialCollectionsLab.WorkOrder("KEEP-2", false)));
        SequentialCollectionsLab.removeCancelled(orders);
        check(orders.size() == 2, "remove all adjacent cancelled"); assertions++;
        check("KEEP-1".equals(orders.getFirst().id()), "keeps first"); assertions++;
        check("KEEP-2".equals(orders.getLast().id()), "keeps last"); assertions++;
        check(input.equals(List.of("WO-201", "WO-202", "WO-201")), "input unchanged"); assertions++;

        System.out.println("report.input=" + String.join(",", input));
        System.out.println("report.fifo=" + String.join(",", fifo));
        System.out.println("report.lifo=" + String.join(",", lifo));
        System.out.println("report.snapshot=" + String.join(",", snapshot)
                + ";view=" + String.join(",", view));
        System.out.println("assertions=" + assertions + " passed");
    }

    private static void expectUnsupported(Runnable action) {
        try {
            action.run();
            throw new AssertionError("expected UnsupportedOperationException");
        } catch (UnsupportedOperationException expected) {
            // The exact exception message is deliberately not part of the oracle.
        }
    }

    private static void check(boolean condition, String message) {
        if (!condition) {
            throw new AssertionError(message);
        }
    }
}
