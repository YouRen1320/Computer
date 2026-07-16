package academy.aftercommit;

import java.util.UUID;
import org.junit.jupiter.api.Test;
import static org.assertj.core.api.Assertions.*;

class AfterCommitBoundaryTest {
    private static AfterCommitBoundary.Fixture open() { return AfterCommitBoundary.open("ac" + UUID.randomUUID().toString().replace("-", "")); }
    @Test void commitPersistsThenPublishes() { try (var f = open()) { f.service().create("wo-1", false); assertThat(f.rows()).isOne(); assertThat(f.published()).containsExactly("wo-1"); } }
    @Test void rollbackMustNotPublish() { try (var f = open()) { assertThatThrownBy(() -> f.service().create("wo-1", true)); assertThat(f.rows()).isZero(); assertThat(f.published()).as("EXPECTED_AFTER_COMMIT_ONLY").isEmpty(); } }
}
