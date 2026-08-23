import java.util.ArrayList;
import java.util.List;
import java.util.function.Predicate;

public final class HiddenSideEffectFailure {
    private HiddenSideEffectFailure() {
    }

    public static void main(String[] args) {
        List<String> audit = new ArrayList<>();
        Predicate<String> valid = id -> {
            audit.add(id);
            return id.startsWith("WO-");
        };
        valid.test("WO-101");
        valid.test("WO-101");
        if (!audit.isEmpty()) {
            throw new IllegalStateException("HIDDEN_SIDE_EFFECT writes=" + audit.size());
        }
    }
}
