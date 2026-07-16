import java.util.ArrayDeque;
import java.util.Queue;

public final class EmptyQueueRemoveFailure {
    private EmptyQueueRemoveFailure() {
    }

    public static void main(String[] args) {
        Queue<String> queue = new ArrayDeque<>();
        queue.remove();
    }
}
