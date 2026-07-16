package academy.fakeintegration;

import java.util.Optional;
import java.util.concurrent.atomic.AtomicInteger;
import org.springframework.jdbc.core.JdbcTemplate;

/** Exercise fixture: the starter deliberately wires a fake while claiming repository integration. */
public final class RepositoryBoundary {
    private RepositoryBoundary() {}
    public record WorkOrder(String tenantId, String id, String status) {}
    public interface WorkOrders { Optional<WorkOrder> find(String tenantId, String id); int sqlExecutions(); }
    public static final class FakeWorkOrders implements WorkOrders {
        public Optional<WorkOrder> find(String tenantId, String id) { return Optional.of(new WorkOrder(tenantId, id, "OPEN")); }
        public int sqlExecutions() { return 0; }
    }
    public static final class JdbcWorkOrders implements WorkOrders {
        private final JdbcTemplate jdbc; private final AtomicInteger executions = new AtomicInteger();
        public JdbcWorkOrders(JdbcTemplate jdbc) { this.jdbc = jdbc; }
        public Optional<WorkOrder> find(String tenantId, String id) {
            executions.incrementAndGet();
            return jdbc.query("select tenant_id,id,status from work_order where tenant_id=? and id=?", (rs, n) -> new WorkOrder(rs.getString(1),rs.getString(2),rs.getString(3)), tenantId,id).stream().findFirst();
        }
        public int sqlExecutions() { return executions.get(); }
    }
    public static WorkOrders open() { return new FakeWorkOrders(); }
}
