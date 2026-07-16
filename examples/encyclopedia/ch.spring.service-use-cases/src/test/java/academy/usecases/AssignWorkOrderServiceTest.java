package academy.usecases;

import academy.usecases.application.*;
import academy.usecases.application.AssignWorkOrderService.*;
import academy.usecases.application.AssignWorkOrderUseCase.*;
import academy.usecases.domain.WorkOrder;
import academy.usecases.web.AssignWorkOrderController;
import java.util.*;
import org.junit.jupiter.api.Test;
import org.springframework.transaction.annotation.Transactional;
import static org.assertj.core.api.Assertions.*;

class AssignWorkOrderServiceTest {
    @Test void orchestrationHasBusinessOrder(){var f=fixture(triaged());f.service.assign(command(0));assertThat(f.events).containsExactly("load","save:ASSIGNED","audit","outbox");}
    @Test void resultContainsCommittedIntent(){var f=fixture(triaged());assertThat(f.service.assign(command(0))).isEqualTo(new AssignResult("wo-1","ASSIGNED",1,"team-a","tech-a"));}
    @Test void notFoundStopsSubsequentPorts(){var f=fixture(null);assertThatThrownBy(()->f.service.assign(command(0))).isInstanceOf(WorkOrderNotFound.class);assertThat(f.events).containsExactly("load");}
    @Test void domainRejectsInvalidStateBeforeSave(){var f=fixture(new WorkOrder("tenant-a","wo-1",WorkOrder.State.ASSIGNED,1));assertThatThrownBy(()->f.service.assign(command(1))).isInstanceOf(IllegalStateException.class);assertThat(f.events).containsExactly("load");}
    @Test void domainRejectsStaleVersionBeforeSave(){var f=fixture(triaged());assertThatThrownBy(()->f.service.assign(command(9))).isInstanceOf(WorkOrder.VersionConflict.class);assertThat(f.events).containsExactly("load");}
    @Test void repositoryPortIsReplaceable(){var f=fixture(triaged());assertThat(f.service.assign(command(0)).state()).isEqualTo("ASSIGNED");assertThat(f.repository).isInstanceOf(RecordingRepository.class);}
    @Test void controllerOnlyMapsProtocol(){var captured=new ArrayList<AssignCommand>();AssignWorkOrderUseCase useCase=c->{captured.add(c);return new AssignResult(c.workOrderId(),"ASSIGNED",8,c.teamId(),c.technicianId());};var controller=new AssignWorkOrderController(useCase);var response=controller.post(new AssignWorkOrderController.AuthContext("trusted-tenant","actor-7"),"wo-9",new AssignWorkOrderController.Request("team-x","tech-x",7));assertThat(captured).containsExactly(new AssignCommand("trusted-tenant","actor-7","wo-9","team-x","tech-x",7));assertThat(response).isEqualTo(new AssignWorkOrderController.Response("wo-9","ASSIGNED",8));}
    @Test void domainTypeHasNoFrameworkAnnotations(){assertThat(WorkOrder.class.getAnnotations()).isEmpty();}
    @Test void publicUseCaseDeclaresTransactionIntent() throws Exception {assertThat(AssignWorkOrderService.class.getMethod("assign",AssignCommand.class).isAnnotationPresent(Transactional.class)).isTrue();}
    private static WorkOrder triaged(){return new WorkOrder("tenant-a","wo-1",WorkOrder.State.TRIAGED,0);} private static AssignCommand command(long version){return new AssignCommand("tenant-a","actor-a","wo-1","team-a","tech-a",version);}
    private static Fixture fixture(WorkOrder workOrder){var events=new ArrayList<String>();var repository=new RecordingRepository(workOrder,events);return new Fixture(new AssignWorkOrderService(repository,(a,b,c,d)->events.add("audit"),(a,b,c)->events.add("outbox")),repository,events);}
    record Fixture(AssignWorkOrderService service,RecordingRepository repository,List<String> events){}
    static final class RecordingRepository implements WorkOrderRepository {private final WorkOrder workOrder;private final List<String> events;RecordingRepository(WorkOrder w,List<String> e){workOrder=w;events=e;}public Optional<WorkOrder> find(String t,String id){events.add("load");return Optional.ofNullable(workOrder);}public void save(WorkOrder w,long expected){events.add("save:"+w.state());}}
}
