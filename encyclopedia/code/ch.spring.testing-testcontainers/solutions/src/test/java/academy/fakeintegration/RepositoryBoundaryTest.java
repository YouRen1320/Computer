package academy.fakeintegration;

import org.junit.jupiter.api.*;
import static org.assertj.core.api.Assertions.*;

class RepositoryBoundaryTest {
    private RepositoryBoundary.WorkOrders repository;
    @BeforeEach void openFixture() { repository = RepositoryBoundary.open(); }
    @Test void fixtureCanReturnAWorkOrder() { assertThat(repository.find("tenant-a", "wo-1")).isPresent(); }
    @Test void advertisedIntegrationActuallyExecutesSql() { repository.find("tenant-a", "wo-1"); assertThat(repository.sqlExecutions()).as("EXPECTED_REAL_SQL_BOUNDARY").isOne(); }
}
