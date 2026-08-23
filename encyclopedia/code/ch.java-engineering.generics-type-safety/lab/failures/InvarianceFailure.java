import java.util.ArrayList;
import java.util.List;

final class InvarianceFailure {
    void fail() {
        List<Integer> integers = new ArrayList<>();
        List<Number> numbers = integers;
    }
}
