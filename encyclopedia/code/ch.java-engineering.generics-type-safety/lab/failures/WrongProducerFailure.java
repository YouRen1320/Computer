import java.util.List;

final class WrongProducerFailure {
    static <T> T first(List<? super T> values) {
        return values.getFirst();
    }
}
