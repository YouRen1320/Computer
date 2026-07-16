import java.util.ArrayList;
import java.util.List;
import java.util.function.Predicate;

public final class HiddenSideEffectFailure {
    private HiddenSideEffectFailure() {
    }

    public static void main(String[] args) {
        List<String> audit = new ArrayList<>();
        Predicate<Integer> positive = value -> {
            audit.add("checked:" + value);
            return value > 0;
        };
        positive.test(4);
        positive.test(4);
        if (audit.size() != 0) {
            throw new IllegalStateException("HIDDEN_SIDE_EFFECT writes=" + audit.size());
        }
    }
}
