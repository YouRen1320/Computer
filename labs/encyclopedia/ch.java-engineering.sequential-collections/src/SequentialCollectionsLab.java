import java.util.ArrayDeque;
import java.util.ArrayList;
import java.util.Collections;
import java.util.Deque;
import java.util.Iterator;
import java.util.List;
import java.util.Queue;

final class SequentialCollectionsLab {
    private SequentialCollectionsLab() {
    }

    static List<String> dispatchInFifoOrder(List<String> ids) {
        Queue<String> queue = new ArrayDeque<>();
        queue.addAll(ids);
        List<String> result = new ArrayList<>();
        String id;
        while ((id = queue.poll()) != null) {
            result.add(id);
        }
        return List.copyOf(result);
    }

    static List<String> undoInLifoOrder(List<String> actions) {
        Deque<String> stack = new ArrayDeque<>();
        for (String action : actions) {
            stack.addLast(action);
        }
        List<String> result = new ArrayList<>();
        while (!stack.isEmpty()) {
            result.add(stack.removeLast());
        }
        return List.copyOf(result);
    }

    static void removeCancelled(List<WorkOrder> orders) {
        Iterator<WorkOrder> iterator = orders.iterator();
        while (iterator.hasNext()) {
            if (iterator.next().cancelled()) {
                iterator.remove();
            }
        }
    }

    static List<String> readOnlyView(List<String> source) {
        return Collections.unmodifiableList(source);
    }

    static List<String> snapshot(List<String> source) {
        return List.copyOf(source);
    }

    record WorkOrder(String id, boolean cancelled) {
    }
}
