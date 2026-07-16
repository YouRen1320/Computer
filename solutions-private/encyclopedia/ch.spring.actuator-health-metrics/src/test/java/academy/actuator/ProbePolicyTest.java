package academy.actuator;

import org.junit.jupiter.api.Test;
import static org.assertj.core.api.Assertions.*;

class ProbePolicyTest {
    @Test void healthyDependencyKeepsBothSignalsUp() { assertThat(ProbePolicy.evaluate(true,true)).isEqualTo(new ProbePolicy.Signals(true,true)); }
    @Test void databaseFailureMustOnlyRemoveReadiness() { assertThat(ProbePolicy.evaluate(true,false)).as("EXPECTED_LIVENESS_INDEPENDENT_FROM_DATABASE").isEqualTo(new ProbePolicy.Signals(true,false)); }
}
