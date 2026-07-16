import java.util.ArrayDeque;
import java.util.ArrayList;
import java.util.Collections;
import java.util.Deque;
import java.util.List;
import java.util.Queue;

public final class SequentialCollectionsChallenge {
    private SequentialCollectionsChallenge() {
    }

    public static void main(String[] args) {
        int assertions = 0;
        List<String> input = List.of("WO-401", "WO-402", "WO-403");
        List<String> dispatched = dispatch(input);
        check(dispatched.equals(input), "dispatch must be FIFO"); assertions++;
        check(input.equals(List.of("WO-401", "WO-402", "WO-403")), "input unchanged"); assertions++;
        check(dispatch(List.of()).isEmpty(), "empty dispatch"); assertions++;

        List<String> actions = List.of("assign:401", "assign:402", "assign:403");
        List<String> undone = undo(actions);
        check(undone.equals(List.of("assign:403", "assign:402", "assign:401")), "undo must be LIFO"); assertions++;
        check(actions.getFirst().equals("assign:401"), "actions unchanged"); assertions++;

        List<String> source = new ArrayList<>(List.of("RECEIVED", "VALIDATED"));
        List<String> snapshot = publishedSnapshot(source);
        source.add("ASSIGNED");
        check(snapshot.size() == 2, "snapshot must be stable"); assertions++;
        check(snapshot.getLast().equals("VALIDATED"), "snapshot content"); assertions++;
        expectUnsupported(() -> snapshot.add("CLOSED")); assertions++;

        List<WorkOrder> orders = new ArrayList<>(List.of(
                new WorkOrder("KEEP-1", false),
                new WorkOrder("CANCEL-1", true),
                new WorkOrder("CANCEL-2", true),
                new WorkOrder("KEEP-2", false)));
        removeCancelled(orders);
        check(orders.size() == 2, "remove adjacent cancelled"); assertions++;
        check(orders.getFirst().id().equals("KEEP-1"), "keep first"); assertions++;
        check(orders.getLast().id().equals("KEEP-2"), "keep last"); assertions++;
        check(orders.stream().noneMatch(WorkOrder::cancelled), "no cancelled remains"); assertions++;

        System.out.println("exercise.assertions=" + assertions + " passed");
    }

    // TODO 1：让最早进入的工单最早离开，并返回不可修改结果。
    static List<String> dispatch(List<String> input) {
        Deque<String> queue = new ArrayDeque<>(input);
        List<String> result = new ArrayList<>();
        while (!queue.isEmpty()) {
            result.add(queue.removeLast());
        }
        return List.copyOf(result);
    }

    // TODO 2：让最后记录的动作最先撤销。
    static List<String> undo(List<String> actions) {
        Queue<String> queue = new ArrayDeque<>(actions);
        List<String> result = new ArrayList<>();
        while (!queue.isEmpty()) {
            result.add(queue.remove());
        }
        return List.copyOf(result);
    }

    // TODO 3：返回与源列表后续结构修改隔离的不可修改浅快照。
    static List<String> publishedSnapshot(List<String> source) {
        return Collections.unmodifiableList(source);
    }

    // TODO 4：删除所有取消项，不能因索引左移而跳过相邻元素。
    static void removeCancelled(List<WorkOrder> orders) {
        for (int index = 0; index < orders.size(); index++) {
            if (orders.get(index).cancelled()) {
                orders.remove(index);
            }
        }
    }

    private static void expectUnsupported(Runnable action) {
        try {
            action.run();
            throw new AssertionError("expected UnsupportedOperationException");
        } catch (UnsupportedOperationException expected) {
            // Expected contract; message text is intentionally ignored.
        }
    }

    private static void check(boolean condition, String message) {
        if (!condition) {
            throw new AssertionError(message);
        }
    }

    record WorkOrder(String id, boolean cancelled) {
    }
}
