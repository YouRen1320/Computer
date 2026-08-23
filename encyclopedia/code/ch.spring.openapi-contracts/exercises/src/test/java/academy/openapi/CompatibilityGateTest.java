package academy.openapi;

import java.util.Set;
import org.junit.jupiter.api.Test;
import static org.assertj.core.api.Assertions.*;

class CompatibilityGateTest {
    @Test void addingOptionalPropertyKeepsRequiredPromise() { assertThat(CompatibilityGate.compatible(Set.of("id","status","version"), Set.of("id","status","version"))).isTrue(); }
    @Test void deletingRequiredResponseFieldMustBeBlocked() { assertThat(CompatibilityGate.compatible(Set.of("id","status","version"), Set.of("id","status"))).as("EXPECTED_BREAKING_CHANGE_BLOCKED").isFalse(); }
}
