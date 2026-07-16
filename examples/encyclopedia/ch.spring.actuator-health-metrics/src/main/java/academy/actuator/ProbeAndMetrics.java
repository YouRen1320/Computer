package academy.actuator;

import io.micrometer.core.instrument.simple.SimpleMeterRegistry;
import java.util.Set;

/** Small policy keeps restart signals independent from external dependencies and meter tags bounded. */
public final class ProbeAndMetrics {
    private ProbeAndMetrics() {}
    public enum Signal { UP, DOWN }
    public record Probes(Signal liveness, Signal readiness) {}
    public static Probes probes(boolean processHealthy, boolean databaseUp) {
        return new Probes(processHealthy ? Signal.UP : Signal.DOWN, processHealthy && databaseUp ? Signal.UP : Signal.DOWN);
    }
    public static final class WorkOrderMeters implements AutoCloseable {
        private static final Set<String> PRIORITIES = Set.of("P1","P2","P3","P4");
        private final SimpleMeterRegistry registry = new SimpleMeterRegistry();
        public void created(String priority, String ignoredWorkOrderId) {
            if (!PRIORITIES.contains(priority)) throw new IllegalArgumentException("bounded priority required");
            registry.counter("factorycare.workorders.created", "result", "success", "priority", priority).increment();
        }
        public SimpleMeterRegistry registry() { return registry; }
        @Override public void close() { registry.close(); }
    }
}
