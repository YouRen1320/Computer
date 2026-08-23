package academy.repositories;

import academy.repositories.adapter.MyBatisWorkOrderRepository;
import academy.repositories.adapter.MyBatisWorkOrderRepository.WorkOrderMapper;
import academy.repositories.domain.WorkOrderRepository;
import academy.repositories.domain.WorkOrderRepository.*;
import com.zaxxer.hikari.HikariConfig;
import com.zaxxer.hikari.HikariDataSource;
import java.util.Optional;
import org.apache.ibatis.session.Configuration;
import org.junit.jupiter.api.*;
import org.mybatis.spring.SqlSessionFactoryBean;
import org.mybatis.spring.SqlSessionTemplate;
import static org.assertj.core.api.Assertions.*;

class MyBatisWorkOrderRepositoryTest {
    HikariDataSource dataSource; WorkOrderRepository repository;
    TenantId tenant = new TenantId("factory-a"); WorkOrderId id = new WorkOrderId("wo-42");

    @BeforeEach void setUp() throws Exception {
        var hikari = new HikariConfig(); hikari.setJdbcUrl("jdbc:h2:mem:repo" + System.nanoTime()); hikari.setUsername("sa"); hikari.setMaximumPoolSize(2); dataSource = new HikariDataSource(hikari);
        try (var connection = dataSource.getConnection(); var statement = connection.createStatement()) { statement.execute("create table work_order(tenant_id varchar(64), id varchar(64), status varchar(32), version bigint, primary key(tenant_id,id))"); }
        var configuration = new Configuration(); configuration.setMapUnderscoreToCamelCase(true); configuration.addMapper(WorkOrderMapper.class);
        var factoryBean = new SqlSessionFactoryBean(); factoryBean.setDataSource(dataSource); factoryBean.setConfiguration(configuration);
        var template = new SqlSessionTemplate(factoryBean.getObject()); repository = new MyBatisWorkOrderRepository(template.getMapper(WorkOrderMapper.class));
    }
    @AfterEach void close() { dataSource.close(); }

    @Test void portHasNoFrameworkAnnotation() { assertThat(WorkOrderRepository.class.getAnnotations()).isEmpty(); }
    @Test void saveAndFindReconstructDomain() { var expected = work(tenant, id, Status.CREATED, 0); repository.save(expected); assertThat(repository.find(tenant,id)).contains(expected); }
    @Test void absentIsOptionalEmpty() { assertThat(repository.find(tenant,id)).isEmpty(); }
    @Test void tenantConditionPreventsCrossTenantRead() { var other = new TenantId("factory-b"); repository.save(work(other,id,Status.CREATED,0)); assertThat(repository.find(tenant,id)).isEmpty(); assertThat(repository.find(other,id)).isPresent(); }
    @Test void savePersistsExactlyOneAggregate() { repository.save(work(tenant,id,Status.IN_PROGRESS,3)); assertThat(repository.find(tenant,id).orElseThrow().version()).isEqualTo(3); }
    @Test void matchingVersionUpdatesAndIncrements() { repository.save(work(tenant,id,Status.CREATED,2)); assertThat(repository.updateStatus(tenant,id,2,Status.CLOSED)).isEqualTo(UpdateOutcome.UPDATED); assertThat(repository.find(tenant,id).orElseThrow()).isEqualTo(work(tenant,id,Status.CLOSED,3)); }
    @Test void staleVersionIsConflictAndDoesNotMutate() { repository.save(work(tenant,id,Status.CREATED,2)); assertThat(repository.updateStatus(tenant,id,1,Status.CLOSED)).isEqualTo(UpdateOutcome.VERSION_CONFLICT); assertThat(repository.find(tenant,id).orElseThrow().status()).isEqualTo(Status.CREATED); }
    @Test void zeroRowsForMissingAggregateIsNotFound() { assertThat(repository.updateStatus(tenant,id,0,Status.CLOSED)).isEqualTo(UpdateOutcome.NOT_FOUND); }
    @Test void databaseFailureDoesNotBecomeNotFound() throws Exception { try (var c=dataSource.getConnection(); var s=c.createStatement()) { s.execute("drop table work_order"); } assertThatThrownBy(() -> repository.find(tenant,id)).isInstanceOf(RepositoryUnavailableException.class).hasCauseInstanceOf(org.springframework.dao.DataAccessException.class); }
    private static WorkOrder work(TenantId tenant, WorkOrderId id, Status status, long version) { return new WorkOrder(tenant,id,status,version); }
}
