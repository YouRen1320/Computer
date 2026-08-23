import java.util.LinkedHashMap;
import java.util.Locale;
import java.util.Map;
import java.util.regex.Pattern;

/**
 * Starter for redaction, correlation validation, and evidence-strength gates.
 */
public final class DiagnosticsChallenge {
    private static final Pattern CORRELATION = Pattern.compile("[A-Za-z0-9][A-Za-z0-9._-]{2,63}");

    private DiagnosticsChallenge() {
    }

    public static void main(String[] args) {
        var raw = new LinkedHashMap<String, String>();
        raw.put("order_id", "WO-88");
        raw.put("Authorization", "Bearer-exercise-secret");
        var safe = safeFields(raw);
        require(
                "[REDACTED]".equals(safe.get("authorization")),
                "SECRET_NOT_REDACTED");
        require(
                !safe.containsValue("Bearer-exercise-secret"),
                "SECRET_VALUE_PRESENT");

        require(isValidCorrelation("corr-88"), "VALID_CORRELATION_REJECTED");
        require(!isValidCorrelation("bad\nid"), "LOG_INJECTION_ACCEPTED");
        require(!hasThreadSeries(1), "SINGLE_SNAPSHOT_ACCEPTED");
        require(hasThreadSeries(2), "THREAD_SERIES_REJECTED");
        require(!hasPerformanceEvidence(1, 0), "ONE_SHOT_BENCHMARK_ACCEPTED");
        require(hasPerformanceEvidence(5, 1), "PERFORMANCE_EVIDENCE_REJECTED");

        System.out.println(
                "redaction=true correlation=true thread_series=true performance_gate=true");
        System.out.println("EXERCISE PASS jdk=25");
    }

    static LinkedHashMap<String, String> safeFields(Map<String, String> raw) {
        // TODO normalize keys and redact sensitive values without mutating the input map.
        return new LinkedHashMap<>(raw);
    }

    static boolean isValidCorrelation(String value) {
        // TODO reject null, CR/LF, short, long, or unsupported characters.
        return true;
    }

    static boolean hasThreadSeries(int samples) {
        // TODO require enough snapshots to discuss persistence, not root cause.
        return false;
    }

    static boolean hasPerformanceEvidence(int samples, int warmupIterations) {
        // TODO reject one-shot timing and missing warmup.
        return false;
    }

    static String normalizeKey(String key) {
        return key.toLowerCase(Locale.ROOT).replace('-', '_');
    }

    static Pattern correlationPattern() {
        return CORRELATION;
    }

    private static void require(boolean condition, String marker) {
        if (!condition) {
            throw new IllegalStateException(marker);
        }
    }
}
