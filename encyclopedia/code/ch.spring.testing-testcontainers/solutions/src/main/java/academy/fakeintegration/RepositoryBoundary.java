package academy.fakeintegration;

import java.util.Optional;
import java.util.concurrent.atomic.AtomicInteger;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.datasource.DriverManagerDataSource;

/** Reference fixture crosses the advertised JDBC boundary and counts each real statement. */
public final class RepositoryBoundary {
    private RepositoryBoundary() {}
    public record WorkOrder(String tenantId, String id, String status) {}
    public interface WorkOrders { Optional<WorkOrder> find(String tenantId, String id); int sqlExecutions(); }
    public static final class JdbcWorkOrders implements WorkOrders {
        private final JdbcTemplate jdbc; private final AtomicInteger executions = new AtomicInteger();
        public JdbcWorkOrders(JdbcTemplate jdbc) { this.jdbc = jdbc; }
        public Optional<WorkOrder> find(String tenantId, String id) {
            executions.incrementAndGet();
            return jdbc.query("select tenant_id,id,status from work_order where tenant_id=? and id=?", (rs, n) -> new WorkOrder(rs.getString(1),rs.getString(2),rs.getString(3)), tenantId,id).stream().findFirst();
        }
        public int sqlExecutions() { return executions.get(); }
    }
    public static WorkOrders open() {
        var dataSource = new DriverManagerDataSource("jdbc:h2:mem:solution" + System.nanoTime() + ";DB_CLOSE_DELAY=-1");
        var jdbc = new JdbcTemplate(dataSource);
        jdbc.execute("create table work_order(tenant_id varchar(32),id varchar(32),status varchar(16),primary key(tenant_id,id))");
        jdbc.update("insert into work_order values('tenant-a','wo-1','CREATED')");
        return new JdbcWorkOrders(jdbc);
    }
}
