package academy.testing;

import java.util.Optional;
import org.springframework.http.ResponseEntity;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.web.bind.annotation.*;

/** Small production surface whose web, SQL and assembly boundaries can be tested independently. */
public final class TestingBoundaries {
    private TestingBoundaries() {}

    public record WorkOrder(String tenantId, String id, String status) {}

    public interface WorkOrders {
        Optional<WorkOrder> find(String tenantId, String id);
    }

    public static final class JdbcWorkOrders implements WorkOrders {
        private final JdbcTemplate jdbc;
        public JdbcWorkOrders(JdbcTemplate jdbc) { this.jdbc = jdbc; }
        public Optional<WorkOrder> find(String tenantId, String id) {
            return jdbc.query("select tenant_id,id,status from work_order where tenant_id=? and id=?",
                    (rs, row) -> new WorkOrder(rs.getString(1), rs.getString(2), rs.getString(3)), tenantId, id)
                    .stream().findFirst();
        }
    }

    public static final class LookupService {
        private final WorkOrders workOrders;
        public LookupService(WorkOrders workOrders) { this.workOrders = workOrders; }
        public Optional<WorkOrder> find(String tenantId, String id) { return workOrders.find(tenantId, id); }
    }

    @RestController
    public static final class WorkOrderController {
        private final LookupService service;
        public WorkOrderController(LookupService service) { this.service = service; }
        @GetMapping(value = "/work-orders/{id}", produces = "text/plain")
        ResponseEntity<String> get(@RequestHeader("X-Tenant-Id") String tenantId, @PathVariable String id) {
            return service.find(tenantId, id)
                    .map(order -> ResponseEntity.ok(order.id() + ":" + order.status()))
                    .orElseGet(() -> ResponseEntity.notFound().build());
        }
    }
}
