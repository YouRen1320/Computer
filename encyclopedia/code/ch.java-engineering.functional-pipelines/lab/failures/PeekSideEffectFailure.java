import java.util.ArrayList;
import java.util.List;
import java.util.stream.Stream;

public final class PeekSideEffectFailure {
    private PeekSideEffectFailure() {
    }

    public static void main(String[] args) {
        List<String> audit = new ArrayList<>();
        Stream<String> pipeline = Stream.of("WO-101", "WO-102").peek(audit::add);
        if (!audit.equals(List.of("WO-101", "WO-102"))) {
            throw new IllegalStateException("PEEK_NOT_EXECUTED writes=" + audit.size()
                    + " pipeline=" + pipeline.isParallel());
        }
    }
}
