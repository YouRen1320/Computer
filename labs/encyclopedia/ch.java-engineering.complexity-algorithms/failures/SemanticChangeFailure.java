import java.util.LinkedHashSet;
import java.util.List;
import java.util.Set;

public final class SemanticChangeFailure {
    private SemanticChangeFailure() {
    }

    public static void main(String[] args) {
        List<String> auditEvents = List.of("SCAN-A", "SCAN-B", "SCAN-A");
        Set<String> optimized = new LinkedHashSet<>(auditEvents);
        if (optimized.size() != auditEvents.size()) {
            throw new IllegalStateException("SEMANTIC_CHANGE");
        }
    }
}
