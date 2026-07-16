package academy.usecases;

/** Proven answer: application service coordinates a repository port and aggregate behavior. */
public final class CrudForwardingService {
    private final Repository repository; public CrudForwardingService(Repository repository){this.repository=repository;}
    public void assign(Command command){var workOrder=repository.load(command.workOrderId());workOrder.assign(command.teamId(),command.expectedVersion());repository.save(workOrder,command.expectedVersion());}
    public record Command(String workOrderId,String teamId,long expectedVersion) {}
    public interface Repository { WorkOrder load(String id); void save(WorkOrder workOrder,long expectedVersion); void updateStatus(String id,String state); }
    public interface WorkOrder { void assign(String teamId,long expectedVersion); }
}
