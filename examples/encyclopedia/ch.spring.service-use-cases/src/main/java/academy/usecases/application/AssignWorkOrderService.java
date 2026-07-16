package academy.usecases.application;

import academy.usecases.domain.WorkOrder;
import java.util.Optional;
import org.springframework.transaction.annotation.Transactional;

/** Application service owns use-case ordering and transaction intent, not domain rules. */
public final class AssignWorkOrderService implements AssignWorkOrderUseCase {
    private final WorkOrderRepository repository; private final AuditPort audit; private final OutboxPort outbox;
    public AssignWorkOrderService(WorkOrderRepository repository,AuditPort audit,OutboxPort outbox){this.repository=repository;this.audit=audit;this.outbox=outbox;}
    @Override @Transactional public AssignResult assign(AssignCommand command){
        WorkOrder workOrder=repository.find(command.tenantId(),command.workOrderId()).orElseThrow(WorkOrderNotFound::new);
        workOrder.assign(command.teamId(),command.technicianId(),command.expectedVersion());
        repository.save(workOrder,command.expectedVersion());
        audit.append(command.tenantId(),command.actorId(),command.workOrderId(),"WORK_ORDER_ASSIGNED");
        outbox.append(command.tenantId(),command.workOrderId(),"WorkOrderAssigned.v1");
        return new AssignResult(workOrder.id(),workOrder.state().name(),workOrder.version(),workOrder.teamId(),workOrder.technicianId());
    }
    public interface WorkOrderRepository { Optional<WorkOrder> find(String tenantId,String id); void save(WorkOrder workOrder,long expectedVersion); }
    public interface AuditPort { void append(String tenantId,String actorId,String aggregateId,String action); }
    public interface OutboxPort { void append(String tenantId,String aggregateId,String eventType); }
    public static final class WorkOrderNotFound extends RuntimeException {}
}
