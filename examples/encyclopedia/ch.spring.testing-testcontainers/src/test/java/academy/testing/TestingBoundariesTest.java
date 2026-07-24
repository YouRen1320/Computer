package academy.testing;

import academy.testing.TestingBoundaries.*;
import java.util.Optional;
import javax.sql.DataSource;
import org.h2.jdbcx.JdbcDataSource;
import org.junit.jupiter.api.*;
import org.springframework.context.annotation.*;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;
import static org.assertj.core.api.Assertions.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

class TestingBoundariesTest {
    private JdbcTemplate jdbc;
    private JdbcWorkOrders repository;

    @BeforeEach void database() {
        var dataSource = new JdbcDataSource();
        dataSource.setURL("jdbc:h2:mem:test" + System.nanoTime() + ";DB_CLOSE_DELAY=-1");
        jdbc = new JdbcTemplate(dataSource);
        jdbc.execute("create table work_order(tenant_id varchar(32),id varchar(32),status varchar(16),primary key(tenant_id,id))");
        jdbc.update("insert into work_order values('tenant-a','wo-1','CREATED')");
        repository = new JdbcWorkOrders(jdbc);
    }

    private static MockMvc mvc(WorkOrders port) {
        return MockMvcBuilders.standaloneSetup(new WorkOrderController(new LookupService(port))).build();
    }

    @Test void controllerMapsKnownOrder() throws Exception {
        mvc((tenant, id) -> Optional.of(new WorkOrder(tenant, id, "CREATED")))
                .perform(get("/work-orders/wo-1").header("X-Tenant-Id", "tenant-a"))
                .andExpect(status().isOk()).andExpect(content().string("wo-1:CREATED"));
    }
    @Test void controllerMapsMissingOrderTo404() throws Exception {
        mvc((tenant, id) -> Optional.empty()).perform(get("/work-orders/missing").header("X-Tenant-Id", "tenant-a"))
                .andExpect(status().isNotFound());
    }
    @Test void controllerRequiresTenantHeader() throws Exception {
        mvc((tenant, id) -> Optional.empty()).perform(get("/work-orders/wo-1"))
                .andExpect(status().isBadRequest());
    }
    @Test void repositoryExecutesSelect() { assertThat(repository.find("tenant-a", "wo-1")).contains(new WorkOrder("tenant-a", "wo-1", "CREATED")); }
    @Test void repositoryEnforcesTenantPredicate() { assertThat(repository.find("tenant-b", "wo-1")).isEmpty(); }
    @Test void repositoryReturnsEmptyForMissingId() { assertThat(repository.find("tenant-a", "missing")).isEmpty(); }
    @Test void contextAssemblesCriticalBeanGraph() { try (var context = new AnnotationConfigApplicationContext(Config.class)) { assertThat(context.getBean(WorkOrderController.class)).isNotNull(); } }
    @Test void contextGraphPerformsOneVerticalCall() { try (var context = new AnnotationConfigApplicationContext(Config.class)) { assertThat(context.getBean(LookupService.class).find("tenant-a", "wo-1")).isPresent(); } }

    @Configuration
    static class Config {
        @Bean DataSource dataSource() { var ds = new JdbcDataSource(); ds.setURL("jdbc:h2:mem:context;DB_CLOSE_DELAY=-1;INIT=RUNSCRIPT FROM 'classpath:context-schema.sql'"); return ds; }
        @Bean JdbcTemplate jdbcTemplate(DataSource dataSource) { return new JdbcTemplate(dataSource); }
        @Bean WorkOrders workOrders(JdbcTemplate jdbc) { return new JdbcWorkOrders(jdbc); }
        @Bean LookupService lookupService(WorkOrders workOrders) { return new LookupService(workOrders); }
        @Bean WorkOrderController controller(LookupService service) { return new WorkOrderController(service); }
    }
}
