package academy.testingcontainers;

import java.util.concurrent.atomic.AtomicInteger;
import javax.sql.DataSource;
import org.flywaydb.core.Flyway;
import org.junit.jupiter.api.*;
import org.springframework.context.support.GenericApplicationContext;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.datasource.DriverManagerDataSource;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;
import org.testcontainers.postgresql.PostgreSQLContainer;
import static org.assertj.core.api.Assertions.*;

@Testcontainers
class PostgresContainerLabTest {
    @Container static final PostgreSQLContainer POSTGRES = new PostgreSQLContainer("postgres:18")
            .withDatabaseName("factorycare").withUsername("factorycare").withPassword("factorycare");
    private static final AtomicInteger MIGRATIONS = new AtomicInteger();
    private static DataSource dataSource;
    private JdbcTemplate jdbc;
    private JdbcWorkOrders repository;

    @BeforeAll static void migrateOnce() {
        dataSource = new DriverManagerDataSource(POSTGRES.getJdbcUrl(), POSTGRES.getUsername(), POSTGRES.getPassword());
        Flyway.configure().dataSource(dataSource).locations("classpath:db/migration").load().migrate();
        MIGRATIONS.incrementAndGet();
    }
    @BeforeEach void resetRows() {
        jdbc = new JdbcTemplate(dataSource);
        jdbc.update("delete from work_order");
        repository = new JdbcWorkOrders(jdbc);
    }

    @Test void dependencyIsActuallyPostgresql18() { assertThat(jdbc.queryForObject("show server_version", String.class)).startsWith("18."); }
    @Test void oneSharedContainerRunsOneMigrationLifecycle() { assertThat(POSTGRES.isRunning()).isTrue(); assertThat(MIGRATIONS).hasValue(1); }
    @Test void flywayCreatedRealSchema() { assertThat(jdbc.queryForObject("select count(*) from flyway_schema_history where success", Integer.class)).isOne(); }
    @Test void repositoryRoundTripsThroughRealDriver() { var order = order("tenant-a", "wo-1", 0); repository.insert(order); assertThat(repository.find("tenant-a", "wo-1")).contains(order); }
    @Test void tenantPredicatePreventsCrossTenantRead() { repository.insert(order("tenant-a", "wo-1", 0)); assertThat(repository.find("tenant-b", "wo-1")).isEmpty(); }
    @Test void postgresqlPrimaryKeyRejectsDuplicate() { repository.insert(order("tenant-a", "wo-1", 0)); assertThatThrownBy(() -> repository.insert(order("tenant-a", "wo-1", 0))).isInstanceOf(RuntimeException.class); }
    @Test void optimisticUpdateRequiresExpectedVersion() { repository.insert(order("tenant-a", "wo-1", 0)); assertThat(repository.changeStatus("tenant-a", "wo-1", 0, "ASSIGNED")).isOne(); assertThat(repository.changeStatus("tenant-a", "wo-1", 0, "CLOSED")).isZero(); }
    @Test void contextUsesTheContainerDatasource() {
        try (var context = new GenericApplicationContext()) {
            context.registerBean(DataSource.class, () -> dataSource);
            context.registerBean(JdbcTemplate.class, () -> new JdbcTemplate(context.getBean(DataSource.class)));
            context.registerBean(JdbcWorkOrders.class, () -> new JdbcWorkOrders(context.getBean(JdbcTemplate.class)));
            context.refresh();
            context.getBean(JdbcWorkOrders.class).insert(order("tenant-a", "wo-context", 0));
            assertThat(context.getBean(JdbcWorkOrders.class).find("tenant-a", "wo-context")).isPresent();
        }
    }
    private static JdbcWorkOrders.WorkOrder order(String tenant, String id, long version) { return new JdbcWorkOrders.WorkOrder(tenant, id, "OPEN", version); }
}
