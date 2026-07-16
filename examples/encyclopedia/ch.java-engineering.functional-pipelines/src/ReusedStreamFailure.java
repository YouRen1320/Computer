import java.util.stream.Stream;

public final class ReusedStreamFailure {
    private ReusedStreamFailure() {
    }

    public static void main(String[] args) {
        Stream<String> ids = Stream.of("WO-101", "WO-102");
        ids.count();
        try {
            ids.toList();
        } catch (IllegalStateException expected) {
            throw new IllegalStateException("REUSED_STREAM", expected);
        }
        throw new AssertionError("REUSED_STREAM was not rejected");
    }
}
