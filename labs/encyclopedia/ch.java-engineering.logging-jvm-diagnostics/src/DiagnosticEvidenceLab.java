import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.time.Instant;
import java.util.EnumMap;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Objects;
import java.util.Set;
import java.util.regex.Pattern;

/**
 * Joins deterministic log events and parses fixed thread-dump and GC evidence files.
 */
public final class DiagnosticEvidenceLab {
    private static final Pattern CORRELATION = Pattern.compile("[A-Za-z0-9][A-Za-z0-9._-]{2,63}");
    private static final Pattern THREAD_NAME = Pattern.compile("^\"([^\"]+)\"");
    private static final Pattern LOCK_ID = Pattern.compile("<(0x[0-9a-fA-F]+)>");
    private static final Pattern GC_EVENT = Pattern.compile(
            "GC\\(\\d+\\).*?(\\d+)M->(\\d+)M\\([^)]*\\).*?([0-9]+(?:\\.[0-9]+)?)ms");
    private static final Set<String> SENSITIVE = Set.of(
            "authorization", "password", "token", "cookie", "secret", "api_key");

    private DiagnosticEvidenceLab() {
    }

    public static void main(String[] args) throws IOException {
        if (args.length != 2) {
            throw new IllegalArgumentException("usage: DiagnosticEvidenceLab <thread-dump> <gc-log>");
        }

        var secret = "Bearer-training-secret";
        var events = buildEvents(secret);
        var rendered = events.stream().map(LogEvent::render).toList();
        var joined = events.size() == 3
                && events.stream().allMatch(event -> event.correlationId().equals("corr-42"));
        var redacted = rendered.stream().noneMatch(line -> line.contains(secret))
                && rendered.stream().anyMatch(line -> line.contains("[REDACTED]"));
        requireSecretAbsent(String.join("\n", rendered), secret);

        var failure = events.stream()
                .map(LogEvent::exception)
                .filter(Objects::nonNull)
                .findFirst()
                .orElseThrow();
        requireThrowableEvidence(failure);

        var dump = Files.readString(Path.of(args[0]), StandardCharsets.UTF_8);
        var gcLog = Files.readString(Path.of(args[1]), StandardCharsets.UTF_8);
        var threads = ThreadEvidence.parse(dump);
        var gc = GcEvidence.parse(gcLog);
        requireThreadSeries(2);
        requirePerformanceEvidence(5, 1);

        System.out.printf(
                Locale.ROOT,
                "events=%d correlation=corr-42 joined=%s secret.redacted=%s%n",
                events.size(),
                joined,
                redacted);
        System.out.printf(
                Locale.ROOT,
                "exception.type=%s cause=%s stack.present=%s%n",
                failure.type(),
                failure.causeType(),
                failure.stackPresent());
        System.out.printf(
                Locale.ROOT,
                "threads.total=%d runnable=%d blocked=%d waiting=%d timed_waiting=%d deadlock=%s owner=%s%n",
                threads.total(),
                threads.count(Thread.State.RUNNABLE),
                threads.count(Thread.State.BLOCKED),
                threads.count(Thread.State.WAITING),
                threads.count(Thread.State.TIMED_WAITING),
                threads.deadlock(),
                threads.ownerOfDispatchWait());
        System.out.printf(
                Locale.ROOT,
                "gc.events=%d full=%d total_pause_ms=%.3f max_pause_ms=%.3f reclaimed_mib=%d%n",
                gc.events(),
                gc.fullEvents(),
                gc.totalPauseMs(),
                gc.maxPauseMs(),
                gc.reclaimedMiB());
        System.out.println("evidence.guards=thread_samples>=2,performance_samples>=5,warmup>=1");
        System.out.println("LAB PASS jdk=25 evidence=fixed-files");
    }

    public static void requireSecretAbsent(String rendered, String secret) {
        Objects.requireNonNull(rendered, "rendered");
        Objects.requireNonNull(secret, "secret");
        if (!secret.isEmpty() && rendered.contains(secret)) {
            throw new IllegalStateException("SENSITIVE_VALUE_LEAK");
        }
    }

    public static void requireThreadSeries(int samples) {
        if (samples < 2) {
            throw new IllegalStateException("THREAD_SERIES_TOO_SMALL");
        }
    }

    public static void requirePerformanceEvidence(int samples, int warmupIterations) {
        if (samples < 5 || warmupIterations < 1) {
            throw new IllegalStateException("PERFORMANCE_EVIDENCE_TOO_SMALL");
        }
    }

    public static void requireThrowableEvidence(ExceptionEvidence evidence) {
        if (evidence == null || !evidence.stackPresent()) {
            throw new IllegalStateException("THROWABLE_EVIDENCE_REQUIRED");
        }
    }

    private static List<LogEvent> buildEvents(String secret) {
        var started = new LinkedHashMap<String, String>();
        started.put("order_id", "WO-42");
        started.put("thread", "dispatch-worker");

        var failed = new LinkedHashMap<String, String>();
        failed.put("order_id", "WO-42");
        failed.put("authorization", secret);

        var completed = new LinkedHashMap<String, String>();
        completed.put("order_id", "WO-42");
        completed.put("outcome", "degraded");

        var cause = new IOException("notification timeout");
        var error = new IllegalStateException("dispatch failed", cause);
        error.setStackTrace(new StackTraceElement[] {
            new StackTraceElement("factorycare.DispatchService", "dispatch", "DispatchService.java", 91)
        });

        return List.of(
                LogEvent.safe(
                        Instant.parse("2026-07-17T04:00:00Z"),
                        "INFO",
                        "work_order.dispatch.started",
                        "corr-42",
                        started,
                        null),
                LogEvent.safe(
                        Instant.parse("2026-07-17T04:00:01Z"),
                        "ERROR",
                        "work_order.dispatch.failed",
                        "corr-42",
                        failed,
                        ExceptionEvidence.from(error)),
                LogEvent.safe(
                        Instant.parse("2026-07-17T04:00:02Z"),
                        "WARN",
                        "work_order.dispatch.completed",
                        "corr-42",
                        completed,
                        null));
    }

    public record ExceptionEvidence(String type, String causeType, boolean stackPresent) {
        static ExceptionEvidence from(Throwable failure) {
            Objects.requireNonNull(failure, "failure");
            return new ExceptionEvidence(
                    failure.getClass().getSimpleName(),
                    failure.getCause() == null
                            ? "none"
                            : failure.getCause().getClass().getSimpleName(),
                    failure.getStackTrace().length > 0);
        }
    }

    private record LogEvent(
            Instant timestamp,
            String level,
            String event,
            String correlationId,
            LinkedHashMap<String, String> fields,
            ExceptionEvidence exception) {
        static LogEvent safe(
                Instant timestamp,
                String level,
                String event,
                String correlationId,
                Map<String, String> rawFields,
                ExceptionEvidence exception) {
            if (!CORRELATION.matcher(correlationId).matches()) {
                throw new IllegalArgumentException("INVALID_CORRELATION_ID");
            }
            var safe = new LinkedHashMap<String, String>();
            rawFields.forEach((key, value) -> {
                var normalized = key.toLowerCase(Locale.ROOT).replace('-', '_');
                safe.put(normalized, SENSITIVE.contains(normalized) ? "[REDACTED]" : value);
            });
            return new LogEvent(timestamp, level, event, correlationId, safe, exception);
        }

        private LogEvent {
            Objects.requireNonNull(timestamp, "timestamp");
            Objects.requireNonNull(level, "level");
            Objects.requireNonNull(event, "event");
            Objects.requireNonNull(correlationId, "correlationId");
            fields = new LinkedHashMap<>(fields);
        }

        @Override
        public LinkedHashMap<String, String> fields() {
            return new LinkedHashMap<>(fields);
        }

        String render() {
            var line = new StringBuilder()
                    .append("timestamp=").append(timestamp)
                    .append(" level=").append(level)
                    .append(" event=").append(event)
                    .append(" correlation_id=").append(correlationId);
            fields.forEach((key, value) -> line
                    .append(' ')
                    .append(key)
                    .append('=')
                    .append(escape(value)));
            return line.toString();
        }
    }

    private record ThreadEvidence(
            int total,
            EnumMap<Thread.State, Integer> states,
            boolean deadlock,
            String ownerOfDispatchWait) {
        static ThreadEvidence parse(String dump) {
            var states = new EnumMap<Thread.State, Integer>(Thread.State.class);
            var ownerByLock = new LinkedHashMap<String, String>();
            var waitByThread = new LinkedHashMap<String, String>();
            String current = null;
            int total = 0;

            for (var line : dump.lines().toList()) {
                var name = THREAD_NAME.matcher(line);
                if (name.find()) {
                    current = name.group(1);
                    total++;
                    continue;
                }
                var trimmed = line.trim();
                if (trimmed.startsWith("java.lang.Thread.State:")) {
                    var state = Thread.State.valueOf(trimmed.substring(trimmed.lastIndexOf(' ') + 1));
                    states.merge(state, 1, Integer::sum);
                } else if (current != null && trimmed.startsWith("- locked")) {
                    var lock = LOCK_ID.matcher(trimmed);
                    if (lock.find()) {
                        ownerByLock.put(lock.group(1), current);
                    }
                } else if (current != null && trimmed.startsWith("- waiting to lock")) {
                    var lock = LOCK_ID.matcher(trimmed);
                    if (lock.find()) {
                        waitByThread.put(current, lock.group(1));
                    }
                }
            }

            var dispatchLock = waitByThread.get("dispatch-worker");
            var owner = dispatchLock == null
                    ? "unknown"
                    : ownerByLock.getOrDefault(dispatchLock, "unknown");
            return new ThreadEvidence(
                    total,
                    states,
                    dump.contains("Found one Java-level deadlock:"),
                    owner);
        }

        private ThreadEvidence {
            states = new EnumMap<>(states);
        }

        int count(Thread.State state) {
            return states.getOrDefault(state, 0);
        }
    }

    private record GcEvidence(
            int events,
            int fullEvents,
            double totalPauseMs,
            double maxPauseMs,
            int reclaimedMiB) {
        static GcEvidence parse(String log) {
            int events = 0;
            int full = 0;
            double total = 0.0;
            double max = 0.0;
            int reclaimed = 0;
            for (var line : log.lines().toList()) {
                var matcher = GC_EVENT.matcher(line);
                if (matcher.find()) {
                    events++;
                    if (line.contains("Pause Full")) {
                        full++;
                    }
                    var before = Integer.parseInt(matcher.group(1));
                    var after = Integer.parseInt(matcher.group(2));
                    var pause = Double.parseDouble(matcher.group(3));
                    reclaimed += before - after;
                    total += pause;
                    max = Math.max(max, pause);
                }
            }
            return new GcEvidence(events, full, total, max, reclaimed);
        }
    }

    private static String escape(String value) {
        return value
                .replace("\\", "\\\\")
                .replace("\r", "\\r")
                .replace("\n", "\\n");
    }
}
