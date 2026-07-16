import java.util.ArrayList;
import java.util.List;
import java.util.function.Predicate;

public final class HiddenPredicateSideEffectContractFailure {
    private HiddenPredicateSideEffectContractFailure() {
    }

    public static void main(String[] args) {
        List<String> writes = new ArrayList<>();
        Predicate<String> rule = id -> {
            writes.add(id);
            return id.startsWith("WO-");
        };
        rule.test("WO-101");
        rule.test("WO-101");
        if (!writes.isEmpty()) {
            throw new IllegalStateException("HIDDEN_SIDE_EFFECT writes=" + writes.size());
        }
    }
}
