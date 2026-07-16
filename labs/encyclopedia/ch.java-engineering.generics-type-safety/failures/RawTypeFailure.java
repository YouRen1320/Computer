import java.util.ArrayList;
import java.util.List;

final class RawTypeFailure {
    void fail() {
        List<String> codes = new ArrayList<>();
        List raw = codes;
        raw.add(42);
    }
}
