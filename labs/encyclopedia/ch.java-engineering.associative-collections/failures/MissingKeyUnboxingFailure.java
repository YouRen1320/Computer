import java.util.HashMap;
import java.util.Map;

public final class MissingKeyUnboxingFailure {
    private MissingKeyUnboxingFailure() {
    }

    public static void main(String[] args) {
        Map<String, Integer> counts = new HashMap<>();
        int missing = counts.get("pump");
        System.out.println(missing);
    }
}
