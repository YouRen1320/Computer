package academy.configuration;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNull;

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

    @Test
    void intuitiveButNonCanonicalNameIsOnlyARelaxedBindingAlias() {
        String aliasEndpoint = "https://alias.example.invalid";

        assertEquals(
                aliasEndpoint,
                EndpointPriorityExercise.resolveEnvironmentOnly(Map.of(
                        "FACTORYCARE_API_BASE_URL",
                        aliasEndpoint)));
    }

    @Test
    void unknownEnvironmentNameDoesNotOverrideTheDefault() {
        assertNull(
                EndpointPriorityExercise.resolveEnvironmentOnly(Map.of(
                        "FACTORYCARE_API_ENDPOINT",
                        "https://unknown.example.invalid")));
    }
}
