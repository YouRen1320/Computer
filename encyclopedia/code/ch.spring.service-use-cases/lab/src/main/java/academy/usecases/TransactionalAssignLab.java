package academy.usecases;

import com.zaxxer.hikari.*;
import java.util.*;
import org.springframework.aop.framework.ProxyFactory;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.datasource.DataSourceTransactionManager;
import org.springframework.transaction.annotation.*;
import org.springframework.transaction.interceptor.TransactionInterceptor;
import org.springframework.transaction.support.TransactionSynchronizationManager;

/** Real local-transaction fixture with application service, domain behavior, ports and JDBC adapter. */
public final class TransactionalAssignLab {
    private TransactionalAssignLab() {}
    public record Command(String tenantId,String actorId,String id,String teamId,String technicianId,long expectedVersion) {}
    public record Result(String id,String state,long version) {}

    public static final class WorkOrder {
        private final String tenantId,id; private String state; private long version; private String teamId,technicianId;
        WorkOrder(String tenantId,String id,String state,long version){this.tenantId=tenantId;this.id=id;this.state=state;this.version=version;}
        void assign(String team,String technician,long expected){if(!"TRIAGED".equals(state))throw new InvalidState();if(version!=expected)throw new VersionConflict();teamId=required(team);technicianId=required(technician);state="ASSIGNED";version++;}
        private static String required(String v){if(v==null||v.isBlank())throw new IllegalArgumentException("required");return v;}
    }
    public interface Store { Optional<WorkOrder> load(String tenantId,String id); void save(WorkOrder order,long expected); void audit(Command command); void outbox(WorkOrder order); }
    public static class AssignService {
        private final Store store; public AssignService(Store store){this.store=store;}
        @Transactional public Result assign(Command command){WorkOrder order=store.load(command.tenantId(),command.id()).orElseThrow(NotFound::new);order.assign(command.teamId(),command.technicianId(),command.expectedVersion());store.save(order,command.expectedVersion());store.audit(command);store.outbox(order);return new Result(order.id,order.state,order.version);}
    }
    public static final class JdbcStore implements Store {
        private final JdbcTemplate jdbc; private final boolean failAudit,failOutbox; private final List<String> events=new ArrayList<>(); private final List<Boolean> active=new ArrayList<>();
        JdbcStore(JdbcTemplate jdbc,boolean failAudit,boolean failOutbox){this.jdbc=jdbc;this.failAudit=failAudit;this.failOutbox=failOutbox;}
        private void event(String name){events.add(name);active.add(TransactionSynchronizationManager.isActualTransactionActive());}
        public Optional<WorkOrder> load(String tenant,String id){event("load");return jdbc.query("select tenant_id,id,state,version from work_order where tenant_id=? and id=?",(rs,n)->new WorkOrder(rs.getString(1),rs.getString(2),rs.getString(3),rs.getLong(4)),tenant,id).stream().findFirst();}
        public void save(WorkOrder order,long expected){event("save");int rows=jdbc.update("update work_order set state=?,version=?,team_id=?,technician_id=? where tenant_id=? and id=? and version=?",order.state,order.version,order.teamId,order.technicianId,order.tenantId,order.id,expected);if(rows!=1)throw new VersionConflict();}
        public void audit(Command command){event("audit");if(failAudit)throw new IllegalStateException("audit unavailable");jdbc.update("insert into audit_log(aggregate_id,action) values(?,?)",command.id(),"WORK_ORDER_ASSIGNED");}
        public void outbox(WorkOrder order){event("outbox");if(failOutbox)throw new IllegalStateException("outbox unavailable");jdbc.update("insert into outbox_event(aggregate_id,event_type) values(?,?)",order.id,"WorkOrderAssigned.v1");}
        public List<String> events(){return List.copyOf(events);} public List<Boolean> transactionActive(){return List.copyOf(active);}
    }
    public static Fixture open(String name,boolean failAudit,boolean failOutbox){
        var config=new HikariConfig();config.setJdbcUrl("jdbc:h2:mem:"+name+";DB_CLOSE_DELAY=-1");config.setUsername("sa");config.setMaximumPoolSize(2);var dataSource=new HikariDataSource(config);var jdbc=new JdbcTemplate(dataSource);
        jdbc.execute("create table work_order(tenant_id varchar(64),id varchar(64),state varchar(32),version bigint,team_id varchar(64),technician_id varchar(64),primary key(tenant_id,id))");jdbc.execute("create table audit_log(aggregate_id varchar(64),action varchar(64))");jdbc.execute("create table outbox_event(aggregate_id varchar(64),event_type varchar(64))");jdbc.update("insert into work_order(tenant_id,id,state,version) values('tenant-a','wo-1','TRIAGED',0)");
        var store=new JdbcStore(jdbc,failAudit,failOutbox);var target=new AssignService(store);var txManager=new DataSourceTransactionManager(dataSource);var interceptor=new TransactionInterceptor(txManager,new AnnotationTransactionAttributeSource());var factory=new ProxyFactory(target);factory.setProxyTargetClass(true);factory.addAdvice(interceptor);return new Fixture((AssignService)factory.getProxy(),store,jdbc,dataSource);
    }
    public record Fixture(AssignService service,JdbcStore store,JdbcTemplate jdbc,HikariDataSource dataSource) implements AutoCloseable {public void close(){dataSource.close();}}
    public static final class NotFound extends RuntimeException {} public static final class InvalidState extends RuntimeException {} public static final class VersionConflict extends RuntimeException {}
}
