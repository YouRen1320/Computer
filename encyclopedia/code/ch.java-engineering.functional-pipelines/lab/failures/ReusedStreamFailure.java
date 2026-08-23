import java.util.stream.Stream;

public final class ReusedStreamFailure {
    private ReusedStreamFailure() {
    }

    public static void main(String[] args) {
        Stream<Integer> values = Stream.of(1, 2, 3);
        values.count();
        try {
            values.toList();
        } catch (IllegalStateException expected) {
            throw new IllegalStateException("REUSED_STREAM", expected);
        }
        throw new AssertionError("REUSED_STREAM was not rejected");
    }
}
