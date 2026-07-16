package academy.usecases.application;

/** Input port uses protocol-independent command and result records. */
public interface AssignWorkOrderUseCase {
    AssignResult assign(AssignCommand command);
    record AssignCommand(String tenantId,String actorId,String workOrderId,String teamId,String technicianId,long expectedVersion) {}
    record AssignResult(String workOrderId,String state,long version,String teamId,String technicianId) {}
}
