package academy.configuration;

import static org.junit.jupiter.api.Assertions.assertEquals;

import java.util.Map;
import org.junit.jupiter.api.Test;

class EndpointPriorityExerciseTest {
    @Test
    void defaultsRemainAvailableWhenTheEnvironmentDoesNotDefineTheProperty() {
        assertEquals(
                EndpointPriorityExercise.DEFAULT_ENDPOINT,
                EndpointPriorityExercise.resolveEndpoint(Map.of()));
    }

    @Test
    void environmentUsesUppercaseUnderscoresAndOverridesTheDefault() {
        String environmentEndpoint = "https://environment.example.invalid";

        assertEquals(
                environmentEndpoint,
                EndpointPriorityExercise.resolveEndpoint(Map.of(
                        EndpointPriorityExercise.ENDPOINT_ENVIRONMENT_VARIABLE,
                        environmentEndpoint)),
                "EXPECTED_ENVIRONMENT_PRECEDENCE");
    }
}
