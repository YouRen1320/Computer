import java.util.ArrayList;
import java.util.List;

public final class ConcurrentModificationFailure {
    private ConcurrentModificationFailure() {
    }

    public static void main(String[] args) {
        List<String> ids = new ArrayList<>(List.of("KEEP", "REMOVE", "TAIL", "LAST"));
        for (String id : ids) {
            if ("REMOVE".equals(id)) {
                ids.remove(id);
            }
        }
    }
}
