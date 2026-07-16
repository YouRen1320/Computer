import java.util.List;

final class WrongConsumerFailure {
    static <T> void add(List<? extends T> values, T value) {
        values.add(value);
    }
}
