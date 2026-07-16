package academy.usecases;

import java.util.*;
import org.junit.jupiter.api.Test;
import static org.assertj.core.api.Assertions.assertThat;

class CrudForwardingServiceTest {
    @Test void commandKeepsUseCaseLanguage(){var c=new CrudForwardingService.Command("wo-1","team-a",3);assertThat(c.teamId()).isEqualTo("team-a");assertThat(c.expectedVersion()).isEqualTo(3);}
    @Test void serviceMustLoadExecuteDomainAndSave(){var events=new ArrayList<String>();var aggregate=(CrudForwardingService.WorkOrder)(team,version)->events.add("domain.assign");var repo=new CrudForwardingService.Repository(){public CrudForwardingService.WorkOrder load(String id){events.add("load");return aggregate;}public void save(CrudForwardingService.WorkOrder w,long v){events.add("save");}public void updateStatus(String id,String state){events.add("crud.update");}};new CrudForwardingService(repo).assign(new CrudForwardingService.Command("wo-1","team-a",3));assertThat(events).as("EXPECTED_USE_CASE_ORCHESTRATION").containsExactly("load","domain.assign","save");}
}
