import java.util.LinkedHashMap;
import java.util.Locale;
import java.util.Map;
import java.util.Set;
import java.util.regex.Pattern;

/**
 * Completed redaction, correlation validation, and evidence-strength gates.
 */
public final class DiagnosticsChallengeSolution {
    private static final Pattern CORRELATION = Pattern.compile("[A-Za-z0-9][A-Za-z0-9._-]{2,63}");
    private static final Set<String> SENSITIVE = Set.of(
            "authorization", "password", "token", "cookie", "secret", "api_key");

    private DiagnosticsChallengeSolution() {
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
        var safe = new LinkedHashMap<String, String>();
        raw.forEach((key, value) -> {
            var normalized = normalizeKey(key);
            safe.put(normalized, SENSITIVE.contains(normalized) ? "[REDACTED]" : value);
        });
        return safe;
    }

    static boolean isValidCorrelation(String value) {
        return value != null && CORRELATION.matcher(value).matches();
    }

    static boolean hasThreadSeries(int samples) {
        return samples >= 2;
    }

    static boolean hasPerformanceEvidence(int samples, int warmupIterations) {
        return samples >= 5 && warmupIterations >= 1;
    }

    private static String normalizeKey(String key) {
        return key.toLowerCase(Locale.ROOT).replace('-', '_');
    }

    private static void require(boolean condition, String marker) {
        if (!condition) {
            throw new IllegalStateException(marker);
        }
    }
}
