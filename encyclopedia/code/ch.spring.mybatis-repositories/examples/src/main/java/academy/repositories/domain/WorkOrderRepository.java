package academy.repositories.domain;

import java.util.Objects;
import java.util.Optional;

/** Application-facing persistence port; this package intentionally imports no persistence framework. */
public interface WorkOrderRepository {
    Optional<WorkOrder> find(TenantId tenantId, WorkOrderId workOrderId);
    void save(WorkOrder workOrder);
    UpdateOutcome updateStatus(TenantId tenantId, WorkOrderId workOrderId, long expectedVersion, Status newStatus);

    record TenantId(String value) { public TenantId { if (value == null || value.isBlank()) throw new IllegalArgumentException("tenantId"); } }
    record WorkOrderId(String value) { public WorkOrderId { if (value == null || value.isBlank()) throw new IllegalArgumentException("workOrderId"); } }
    enum Status { CREATED, IN_PROGRESS, CLOSED }
    enum UpdateOutcome { UPDATED, NOT_FOUND, VERSION_CONFLICT }
    record WorkOrder(TenantId tenantId, WorkOrderId id, Status status, long version) {
        public WorkOrder { Objects.requireNonNull(tenantId); Objects.requireNonNull(id); Objects.requireNonNull(status); if (version < 0) throw new IllegalArgumentException("version"); }
    }
    final class RepositoryUnavailableException extends RuntimeException { public RepositoryUnavailableException(Throwable cause) { super("work-order repository unavailable", cause); } }
}
