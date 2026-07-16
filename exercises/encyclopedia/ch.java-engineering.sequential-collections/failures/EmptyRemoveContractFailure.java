import java.util.ArrayDeque;
import java.util.Queue;

public final class EmptyRemoveContractFailure {
    private EmptyRemoveContractFailure() {
    }

    public static void main(String[] args) {
        Queue<String> queue = new ArrayDeque<>();
        queue.remove();
    }
}
