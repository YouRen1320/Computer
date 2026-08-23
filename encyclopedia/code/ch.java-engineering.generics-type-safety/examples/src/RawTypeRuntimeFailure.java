import java.util.ArrayList;
import java.util.List;

public final class RawTypeRuntimeFailure {
    public static void main(String[] args) {
        List<String> codes = new ArrayList<>();
        List raw = codes;
        raw.add(42);
        String first = codes.getFirst();
        System.out.println(first);
    }
}
