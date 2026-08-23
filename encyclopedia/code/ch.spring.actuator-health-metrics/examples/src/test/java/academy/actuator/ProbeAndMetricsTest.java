package academy.actuator;

import org.junit.jupiter.api.Test;
import static org.assertj.core.api.Assertions.*;

class ProbeAndMetricsTest {
    @Test void healthyProcessAndDatabaseAreReady() { assertThat(ProbeAndMetrics.probes(true,true)).isEqualTo(new ProbeAndMetrics.Probes(ProbeAndMetrics.Signal.UP,ProbeAndMetrics.Signal.UP)); }
    @Test void databaseFailureDoesNotKillLiveness() { assertThat(ProbeAndMetrics.probes(true,false).liveness()).isEqualTo(ProbeAndMetrics.Signal.UP); }
    @Test void databaseFailureRemovesReadiness() { assertThat(ProbeAndMetrics.probes(true,false).readiness()).isEqualTo(ProbeAndMetrics.Signal.DOWN); }
    @Test void brokenProcessFailsBothSignals() { assertThat(ProbeAndMetrics.probes(false,true)).isEqualTo(new ProbeAndMetrics.Probes(ProbeAndMetrics.Signal.DOWN,ProbeAndMetrics.Signal.DOWN)); }
    @Test void successCounterIncrements() { try(var meters=new ProbeAndMetrics.WorkOrderMeters()){meters.created("P1","wo-1");assertThat(meters.registry().get("factorycare.workorders.created").tag("priority","P1").counter().count()).isEqualTo(1);}}
    @Test void workOrderIdDoesNotCreateNewSeries() { try(var meters=new ProbeAndMetrics.WorkOrderMeters()){for(int i=0;i<100;i++)meters.created("P1","wo-"+i);assertThat(meters.registry().getMeters()).hasSize(1);}}
    @Test void boundedPriorityCreatesAtMostFourSeries() { try(var meters=new ProbeAndMetrics.WorkOrderMeters()){for(var p:new String[]{"P1","P2","P3","P4"})meters.created(p,"wo");assertThat(meters.registry().getMeters()).hasSize(4);}}
    @Test void unknownPriorityIsRejectedBeforeMeterCreation() { try(var meters=new ProbeAndMetrics.WorkOrderMeters()){assertThatThrownBy(()->meters.created("tenant-a","wo-1")).isInstanceOf(IllegalArgumentException.class);assertThat(meters.registry().getMeters()).isEmpty();}}
}
