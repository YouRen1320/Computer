package academy.usecases;

/** Starter defect: service forwards a storage status instead of executing aggregate behavior. */
public final class CrudForwardingService {
    private final Repository repository; public CrudForwardingService(Repository repository){this.repository=repository;}
    public void assign(Command command){repository.updateStatus(command.workOrderId(),"ASSIGNED");}
    public record Command(String workOrderId,String teamId,long expectedVersion) {}
    public interface Repository { WorkOrder load(String id); void save(WorkOrder workOrder,long expectedVersion); void updateStatus(String id,String state); }
    public interface WorkOrder { void assign(String teamId,long expectedVersion); }
}
