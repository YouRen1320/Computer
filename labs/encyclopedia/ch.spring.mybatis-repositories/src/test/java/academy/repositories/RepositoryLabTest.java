package academy.repositories;

import academy.repositories.adapter.MyBatisWorkOrderRepository;
import academy.repositories.adapter.MyBatisWorkOrderRepository.WorkOrderMapper;
import academy.repositories.domain.WorkOrderRepository;
import academy.repositories.domain.WorkOrderRepository.*;
import com.zaxxer.hikari.*;
import java.lang.reflect.Method;
import org.apache.ibatis.annotations.*;
import org.apache.ibatis.session.Configuration;
import org.junit.jupiter.api.*;
import org.mybatis.spring.*;
import org.springframework.jdbc.datasource.DataSourceTransactionManager;
import org.springframework.transaction.support.TransactionTemplate;
import static org.assertj.core.api.Assertions.*;

class RepositoryLabTest {
    HikariDataSource dataSource; WorkOrderRepository repository; TenantId tenant = new TenantId("plant-a"); WorkOrderId id = new WorkOrderId("wo-7");
    @BeforeEach void setUp() throws Exception {
        var config=new HikariConfig(); config.setJdbcUrl("jdbc:h2:mem:lab"+System.nanoTime()); config.setUsername("sa"); config.setMaximumPoolSize(2); dataSource=new HikariDataSource(config);
        try(var c=dataSource.getConnection();var s=c.createStatement()){s.execute("create table work_order(tenant_id varchar(64),id varchar(64),status varchar(32),version bigint,primary key(tenant_id,id))");}
        var mybatis=new Configuration(); mybatis.setMapUnderscoreToCamelCase(true); mybatis.addMapper(WorkOrderMapper.class); var bean=new SqlSessionFactoryBean(); bean.setDataSource(dataSource); bean.setConfiguration(mybatis); var template=new SqlSessionTemplate(bean.getObject()); repository=new MyBatisWorkOrderRepository(template.getMapper(WorkOrderMapper.class));
    }
    @AfterEach void close(){dataSource.close();}

    @Test void boundaryIsFrameworkFreeAndMapperIsMarked(){assertThat(WorkOrderRepository.class.getAnnotations()).isEmpty();assertThat(WorkOrderMapper.class).hasAnnotation(Mapper.class);}
    @Test void sqlContainsTenantIdAndVersionConditions() throws Exception {Method find=WorkOrderMapper.class.getMethod("find",String.class,String.class);String read=find.getAnnotation(Select.class).value()[0];Method update=WorkOrderMapper.class.getMethod("update",String.class,String.class,long.class,String.class);String write=update.getAnnotation(Update.class).value()[0];assertThat(read).contains("tenant_id=#{tenantId}","id=#{id}");assertThat(write).contains("tenant_id=#{tenantId}","id=#{id}","version=#{expectedVersion}");}
    @Test void existingRowReconstructsDomain(){var expected=work(tenant,id,Status.OPEN,0);repository.save(expected);assertThat(repository.find(tenant,id)).contains(expected);}
    @Test void missingRowIsEmpty(){assertThat(repository.find(tenant,id)).isEmpty();}
    @Test void sameIdInAnotherTenantDoesNotLeak(){var other=new TenantId("plant-b");repository.save(work(other,id,Status.OPEN,0));assertThat(repository.find(tenant,id)).isEmpty();assertThat(repository.find(other,id)).isPresent();}
    @Test void savePersistsOneRow(){repository.save(work(tenant,id,Status.IN_PROGRESS,4));assertThat(repository.find(tenant,id).orElseThrow().version()).isEqualTo(4);}
    @Test void matchingVersionUpdates(){repository.save(work(tenant,id,Status.OPEN,1));assertThat(repository.updateStatus(tenant,id,1,Status.DONE)).isEqualTo(UpdateOutcome.UPDATED);assertThat(repository.find(tenant,id).orElseThrow()).isEqualTo(work(tenant,id,Status.DONE,2));}
    @Test void staleVersionClassifiesConflict(){repository.save(work(tenant,id,Status.OPEN,1));assertThat(repository.updateStatus(tenant,id,0,Status.DONE)).isEqualTo(UpdateOutcome.VERSION_CONFLICT);}
    @Test void missingTargetClassifiesNotFound(){assertThat(repository.updateStatus(tenant,id,0,Status.DONE)).isEqualTo(UpdateOutcome.NOT_FOUND);}
    @Test void databaseExceptionIsTranslated() throws Exception {try(var c=dataSource.getConnection();var s=c.createStatement()){s.execute("drop table work_order");}assertThatThrownBy(()->repository.find(tenant,id)).isInstanceOf(RepositoryUnavailableException.class).hasCauseInstanceOf(org.springframework.dao.DataAccessException.class);}
    @Test void upperTransactionOwnsRollback(){var tx=new TransactionTemplate(new DataSourceTransactionManager(dataSource));tx.executeWithoutResult(status->{repository.save(work(tenant,id,Status.OPEN,0));status.setRollbackOnly();});assertThat(repository.find(tenant,id)).isEmpty();}
    private static WorkOrder work(TenantId t,WorkOrderId i,Status s,long v){return new WorkOrder(t,i,s,v);}
}
