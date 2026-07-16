import java.util.ArrayDeque;
import java.util.ArrayList;
import java.util.Collections;
import java.util.Deque;
import java.util.Iterator;
import java.util.List;
import java.util.Queue;
import java.util.stream.Collectors;

public final class SequentialCollectionsDemo {
    private SequentialCollectionsDemo() {
    }

    public static void main(String[] args) {
        List<WorkOrder> received = new ArrayList<>(List.of(
                new WorkOrder("WO-101", false),
                new WorkOrder("WO-102", true),
                new WorkOrder("WO-101", false)));
        System.out.println("list.order=" + ids(received));
        System.out.println("list.size=" + received.size());

        Iterator<WorkOrder> iterator = received.iterator();
        while (iterator.hasNext()) {
            if (iterator.next().cancelled()) {
                iterator.remove();
            }
        }
        System.out.println("list.afterIteratorRemove=" + ids(received));

        Queue<String> dispatch = new ArrayDeque<>();
        dispatch.offer("WO-101");
        dispatch.offer("WO-102");
        dispatch.offer("WO-103");
        System.out.println("queue.fifo=" + drainQueue(dispatch));
        System.out.println("queue.empty.poll=" + dispatch.poll());
        System.out.println("queue.empty.peek=" + dispatch.peek());

        Deque<String> undo = new ArrayDeque<>();
        undo.push("assign:WO-101");
        undo.push("assign:WO-102");
        undo.push("assign:WO-103");
        System.out.println("deque.lifo=" + drainStack(undo));

        List<String> timeline = new ArrayList<>(List.of("RECEIVED", "VALIDATED"));
        List<String> view = Collections.unmodifiableList(timeline);
        List<String> snapshot = List.copyOf(timeline);
        timeline.add("ASSIGNED");
        System.out.println("view.size.afterSourceMutation=" + view.size());
        System.out.println("snapshot.size.afterSourceMutation=" + snapshot.size());
        System.out.println("snapshot.first=" + snapshot.getFirst());
    }

    private static String ids(List<WorkOrder> orders) {
        return orders.stream().map(WorkOrder::id).collect(Collectors.joining(","));
    }

    private static String drainQueue(Queue<String> queue) {
        List<String> result = new ArrayList<>();
        String next;
        while ((next = queue.poll()) != null) {
            result.add(next);
        }
        return String.join(",", result);
    }

    private static String drainStack(Deque<String> stack) {
        List<String> result = new ArrayList<>();
        while (!stack.isEmpty()) {
            result.add(stack.pop());
        }
        return String.join(",", result);
    }

    record WorkOrder(String id, boolean cancelled) {
    }
}
