package academy.testingcontainers;

import java.util.Optional;
import org.springframework.jdbc.core.JdbcTemplate;

/** Production-style JDBC adapter; tests must prove this SQL against PostgreSQL rather than a fake. */
public final class JdbcWorkOrders {
    private final JdbcTemplate jdbc;
    public JdbcWorkOrders(JdbcTemplate jdbc) { this.jdbc = jdbc; }
    public record WorkOrder(String tenantId, String id, String status, long version) {}
    public Optional<WorkOrder> find(String tenantId, String id) {
        return jdbc.query("select tenant_id,id,status,version from work_order where tenant_id=? and id=?",
                (rs, row) -> new WorkOrder(rs.getString(1), rs.getString(2), rs.getString(3), rs.getLong(4)), tenantId, id)
                .stream().findFirst();
    }
    public void insert(WorkOrder order) {
        jdbc.update("insert into work_order(tenant_id,id,status,version) values(?,?,?,?)",
                order.tenantId(), order.id(), order.status(), order.version());
    }
    public int changeStatus(String tenantId, String id, long expectedVersion, String status) {
        return jdbc.update("update work_order set status=?,version=version+1 where tenant_id=? and id=? and version=?",
                status, tenantId, id, expectedVersion);
    }
}
