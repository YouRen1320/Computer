package academy.actuator;

import io.micrometer.core.instrument.MeterRegistry;
import java.util.Set;
import java.util.concurrent.atomic.AtomicBoolean;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.boot.health.contributor.*;
import org.springframework.context.annotation.Bean;

@SpringBootApplication
public class ActuatorLabApplication {
    public static void main(String[] args) { SpringApplication.run(ActuatorLabApplication.class, args); }
    @Bean DependencySwitch dependencySwitch() { return new DependencySwitch(); }
    @Bean HealthIndicator databaseHealthIndicator(DependencySwitch dependency) { return () -> dependency.up() ? Health.up().build() : Health.down().withDetail("reason","controlled-lab-outage").build(); }
    @Bean WorkOrderMetrics workOrderMetrics(MeterRegistry registry) { return new WorkOrderMetrics(registry); }

    public static final class DependencySwitch {
        private final AtomicBoolean up = new AtomicBoolean(true);
        public boolean up() { return up.get(); }
        public void set(boolean value) { up.set(value); }
    }
    public static final class WorkOrderMetrics {
        private static final Set<String> PRIORITIES=Set.of("P1","P2","P3","P4"); private final MeterRegistry registry;
        WorkOrderMetrics(MeterRegistry registry) { this.registry=registry; }
        public void created(String priority,String ignoredWorkOrderId) { if(!PRIORITIES.contains(priority))throw new IllegalArgumentException("bounded priority required"); registry.counter("factorycare.workorders.created","result","success","priority",priority).increment(); }
    }
}
