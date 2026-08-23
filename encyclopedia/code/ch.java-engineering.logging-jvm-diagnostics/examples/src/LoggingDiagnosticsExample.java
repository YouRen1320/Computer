import java.io.IOException;
import java.time.Instant;
import java.util.EnumMap;
import java.util.LinkedHashMap;
import java.util.Locale;
import java.util.Map;
import java.util.Objects;
import java.util.Set;
import java.util.regex.Pattern;

/**
 * Renders deterministic structured events and summarizes fixed JVM evidence fixtures.
 */
public final class LoggingDiagnosticsExample {
    private static final Pattern FIELD_NAME = Pattern.compile("[a-z][a-z0-9_]*");
    private static final Pattern CORRELATION_ID = Pattern.compile("[A-Za-z0-9][A-Za-z0-9._-]{2,63}");
    private static final Pattern THREAD_NAME = Pattern.compile("^\"([^\"]+)\"");
    private static final Pattern LOCK_ID = Pattern.compile("<(0x[0-9a-fA-F]+)>");
    private static final Pattern GC_EVENT = Pattern.compile(
            "GC\\(\\d+\\).*?(\\d+)M->(\\d+)M\\([^)]*\\).*?([0-9]+(?:\\.[0-9]+)?)ms");
    private static final Set<String> SENSITIVE_KEYS = Set.of(
            "authorization", "password", "token", "cookie", "secret", "api_key");

    private LoggingDiagnosticsExample() {
    }

    public static void main(String[] args) {
        var rawFields = new LinkedHashMap<String, String>();
        rawFields.put("correlation_id", "corr-7");
        rawFields.put("order_id", "WO-7");
        rawFields.put("authorization", "Bearer-demo-secret");
        rawFields.put("detail", "pump\nstopped");
        var event = new StructuredEvent(
                Instant.parse("2026-07-17T04:00:00Z"),
                Level.INFO,
                "work_order.accepted",
                redact(rawFields));
        var rendered = event.render();

        requireValidCorrelation(event.fields().get("correlation_id"));
        requireSecretAbsent(rendered, "Bearer-demo-secret");

        var cause = new IOException("downstream unavailable");
        var failure = new IllegalStateException("dispatch failed", cause);
        failure.setStackTrace(new StackTraceElement[] {
            new StackTraceElement("factorycare.DispatchService", "dispatch", "DispatchService.java", 42)
        });
        var exception = ExceptionEvidence.from(failure);
        var threads = ThreadDumpSummary.parse(THREAD_DUMP);
        var gc = GcSummary.parse(GC_LOG);

        System.out.println(rendered);
        System.out.printf(
                Locale.ROOT,
                "correlation.valid=true secret.absent=true exception.type=%s cause=%s stack.present=%s%n",
                exception.type(),
                exception.causeType(),
                exception.stackPresent());
        System.out.printf(
                Locale.ROOT,
                "threads.total=%d blocked=%d waiting=%d lock.owner=%s%n",
                threads.total(),
                threads.count(Thread.State.BLOCKED),
                threads.count(Thread.State.WAITING),
                threads.lockOwner());
        System.out.printf(
                Locale.ROOT,
                "gc.events=%d total_pause_ms=%.3f max_pause_ms=%.3f reclaimed_mib=%d%n",
                gc.events(),
                gc.totalPauseMs(),
                gc.maxPauseMs(),
                gc.reclaimedMiB());
        System.out.println("EXAMPLE PASS jdk=25 evidence=fixed-fixtures");
    }

    public static void requireValidCorrelation(String value) {
        if (value == null || !CORRELATION_ID.matcher(value).matches()) {
            throw new IllegalArgumentException("INVALID_CORRELATION_ID");
        }
    }

    public static void requireSecretAbsent(String rendered, String secret) {
        Objects.requireNonNull(rendered, "rendered");
        Objects.requireNonNull(secret, "secret");
        if (!secret.isEmpty() && rendered.contains(secret)) {
            throw new IllegalStateException("SENSITIVE_VALUE_LEAK");
        }
    }

    private static LinkedHashMap<String, String> redact(Map<String, String> fields) {
        var safe = new LinkedHashMap<String, String>();
        fields.forEach((key, value) -> {
            var normalized = key.toLowerCase(Locale.ROOT).replace('-', '_');
            if (!FIELD_NAME.matcher(normalized).matches()) {
                throw new IllegalArgumentException("invalid field name: " + key);
            }
            safe.put(normalized, SENSITIVE_KEYS.contains(normalized) ? "[REDACTED]" : value);
        });
        return safe;
    }

    private static String escape(String value) {
        return value
                .replace("\\", "\\\\")
                .replace("\r", "\\r")
                .replace("\n", "\\n");
    }

    private enum Level {
        TRACE,
        DEBUG,
        INFO,
        WARN,
        ERROR
    }

    private record StructuredEvent(
            Instant timestamp,
            Level level,
            String event,
            LinkedHashMap<String, String> fields) {
        private StructuredEvent {
            Objects.requireNonNull(timestamp, "timestamp");
            Objects.requireNonNull(level, "level");
            Objects.requireNonNull(event, "event");
            if (!FIELD_NAME.matcher(event.replace('.', '_')).matches()) {
                throw new IllegalArgumentException("invalid event name: " + event);
            }
            fields = new LinkedHashMap<>(fields);
            requireValidCorrelation(fields.get("correlation_id"));
        }

        @Override
        public LinkedHashMap<String, String> fields() {
            return new LinkedHashMap<>(fields);
        }

        String render() {
            var line = new StringBuilder()
                    .append("timestamp=").append(timestamp)
                    .append(" level=").append(level)
                    .append(" event=").append(event);
            fields.forEach((key, value) -> line
                    .append(' ')
                    .append(key)
                    .append('=')
                    .append(escape(value)));
            return line.toString();
        }
    }

    private record ExceptionEvidence(String type, String causeType, boolean stackPresent) {
        static ExceptionEvidence from(Throwable failure) {
            Objects.requireNonNull(failure, "failure");
            var cause = failure.getCause();
            return new ExceptionEvidence(
                    failure.getClass().getSimpleName(),
                    cause == null ? "none" : cause.getClass().getSimpleName(),
                    failure.getStackTrace().length > 0);
        }
    }

    private record ThreadDumpSummary(
            int total,
            EnumMap<Thread.State, Integer> states,
            String lockOwner) {
        static ThreadDumpSummary parse(String dump) {
            var states = new EnumMap<Thread.State, Integer>(Thread.State.class);
            var owners = new LinkedHashMap<String, String>();
            var waiting = new LinkedHashMap<String, String>();
            String currentThread = null;
            int total = 0;

            for (var line : dump.lines().toList()) {
                var nameMatcher = THREAD_NAME.matcher(line);
                if (nameMatcher.find()) {
                    currentThread = nameMatcher.group(1);
                    total++;
                    continue;
                }
                var trimmed = line.trim();
                if (trimmed.startsWith("java.lang.Thread.State:")) {
                    var state = Thread.State.valueOf(trimmed.substring(trimmed.lastIndexOf(' ') + 1));
                    states.merge(state, 1, Integer::sum);
                } else if (currentThread != null && trimmed.startsWith("- locked")) {
                    var lockMatcher = LOCK_ID.matcher(trimmed);
                    if (lockMatcher.find()) {
                        owners.put(lockMatcher.group(1), currentThread);
                    }
                } else if (currentThread != null && trimmed.startsWith("- waiting to lock")) {
                    var lockMatcher = LOCK_ID.matcher(trimmed);
                    if (lockMatcher.find()) {
                        waiting.put(currentThread, lockMatcher.group(1));
                    }
                }
            }

            var owner = waiting.values().stream()
                    .map(owners::get)
                    .filter(Objects::nonNull)
                    .findFirst()
                    .orElse("unknown");
            return new ThreadDumpSummary(total, states, owner);
        }

        private ThreadDumpSummary {
            states = new EnumMap<>(states);
        }

        int count(Thread.State state) {
            return states.getOrDefault(state, 0);
        }
    }

    private record GcSummary(int events, double totalPauseMs, double maxPauseMs, int reclaimedMiB) {
        static GcSummary parse(String log) {
            int events = 0;
            double total = 0.0;
            double max = 0.0;
            int reclaimed = 0;
            for (var line : log.lines().toList()) {
                var matcher = GC_EVENT.matcher(line);
                if (matcher.find()) {
                    events++;
                    var before = Integer.parseInt(matcher.group(1));
                    var after = Integer.parseInt(matcher.group(2));
                    var pause = Double.parseDouble(matcher.group(3));
                    reclaimed += before - after;
                    total += pause;
                    max = Math.max(max, pause);
                }
            }
            return new GcSummary(events, total, max, reclaimed);
        }
    }

    private static final String THREAD_DUMP = """
            "lock-holder" #21
               java.lang.Thread.State: WAITING
                at factorycare.LockOwner.await(LockOwner.java:10)
                - locked <0x00000001>
            "blocked-worker" #22
               java.lang.Thread.State: BLOCKED
                at factorycare.DispatchService.dispatch(DispatchService.java:42)
                - waiting to lock <0x00000001>
            "event-loop" #23
               java.lang.Thread.State: RUNNABLE
                at factorycare.EventLoop.poll(EventLoop.java:8)
            """;

    private static final String GC_LOG = """
            [0.100s][info][gc] GC(0) Pause Young (Normal) 96M->32M(256M) 4.500ms
            [0.300s][info][gc] GC(1) Pause Young (Normal) 80M->40M(256M) 7.000ms
            """;
}
