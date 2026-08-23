import java.util.ArrayList;
import java.util.List;

final class WrongTargetFailure {
    static void fail() {
        List<Integer> source = List.of(1, 2);
        List<String> target = new ArrayList<>();
        copy(source, target);
    }

    static <T> void copy(List<? extends T> source, List<? super T> target) {
        for (T value : source) {
            target.add(value);
        }
    }
}
