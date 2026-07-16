package academy.transactions;

import com.zaxxer.hikari.*;
import java.util.*;
import org.springframework.aop.framework.ProxyFactory;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.datasource.DataSourceTransactionManager;
import org.springframework.transaction.annotation.*;
import org.springframework.transaction.interceptor.TransactionInterceptor;
import org.springframework.transaction.support.*;

/** Fixture exposes propagation and rollback semantics through real nested Spring proxies. */
public final class PropagationLab {
    private PropagationLab() {}
    public static final class CheckedFailure extends Exception { public CheckedFailure() { super("checked failure"); } }

    public static class AuditService {
        private final JdbcTemplate jdbc; private final List<Boolean> active;
        AuditService(JdbcTemplate jdbc, List<Boolean> active) { this.jdbc = jdbc; this.active = active; }
        @Transactional(propagation = Propagation.REQUIRED) public void required(String id) { write(id, "REQUIRED"); }
        @Transactional(propagation = Propagation.REQUIRES_NEW) public void requiresNew(String id) { write(id, "REQUIRES_NEW"); }
        private void write(String id, String mode) { active.add(TransactionSynchronizationManager.isActualTransactionActive()); jdbc.update("insert into audit_log(work_order_id,mode) values(?,?)", id, mode); }
    }

    public static class WorkOrderService {
        private final JdbcTemplate jdbc; private final AuditService audit; private final List<String> published;
        WorkOrderService(JdbcTemplate jdbc, AuditService audit, List<String> published) { this.jdbc = jdbc; this.audit = audit; this.published = published; }
        private void work(String id) { jdbc.update("insert into work_order(id,status) values(?,'OPEN')", id); }
        @Transactional public void success(String id) { work(id); audit.required(id); afterCommit(id); }
        @Transactional public void requiredThenFail(String id) { work(id); audit.required(id); throw new IllegalStateException("outer failed"); }
        @Transactional public void requiresNewThenFail(String id) { work(id); audit.requiresNew(id); throw new IllegalStateException("outer failed"); }
        @Transactional public void checkedDefault(String id) throws CheckedFailure { work(id); audit.required(id); throw new CheckedFailure(); }
        @Transactional(rollbackFor = CheckedFailure.class) public void checkedRollback(String id) throws CheckedFailure { work(id); audit.required(id); throw new CheckedFailure(); }
        @Transactional public void rollbackAfterRegistration(String id) { work(id); afterCommit(id); throw new IllegalStateException("rollback"); }
        @Transactional public void selfInvocationThenFail(String id) { work(id); selfRequiresNew(id); throw new IllegalStateException("self failed"); }
        @Transactional(propagation = Propagation.REQUIRES_NEW) public void selfRequiresNew(String id) { jdbc.update("insert into audit_log(work_order_id,mode) values(?,'SELF')", id); }
        private void afterCommit(String id) { TransactionSynchronizationManager.registerSynchronization(new TransactionSynchronization() { @Override public void afterCommit() { published.add(id); } }); }
    }

    public static Fixture open(String name) {
        var config = new HikariConfig(); config.setJdbcUrl("jdbc:h2:mem:" + name); config.setUsername("sa"); config.setMaximumPoolSize(3);
        var dataSource = new HikariDataSource(config); var jdbc = new JdbcTemplate(dataSource);
        jdbc.execute("create table work_order(id varchar(64) primary key,status varchar(16))");
        jdbc.execute("create table audit_log(work_order_id varchar(64),mode varchar(32))");
        var manager = new DataSourceTransactionManager(dataSource); var active = new ArrayList<Boolean>(); var published = new ArrayList<String>();
        var auditTarget = new AuditService(jdbc, active); var audit = proxy(auditTarget, manager, AuditService.class);
        var serviceTarget = new WorkOrderService(jdbc, audit, published); var service = proxy(serviceTarget, manager, WorkOrderService.class);
        return new Fixture(service, serviceTarget, audit, jdbc, active, published, dataSource);
    }
    private static <T> T proxy(T target, DataSourceTransactionManager manager, Class<T> type) {
        var factory = new ProxyFactory(target); factory.setProxyTargetClass(true); factory.addAdvice(new TransactionInterceptor(manager, new AnnotationTransactionAttributeSource())); return type.cast(factory.getProxy());
    }
    public record Fixture(WorkOrderService service, WorkOrderService target, AuditService audit, JdbcTemplate jdbc, List<Boolean> active, List<String> published, HikariDataSource dataSource) implements AutoCloseable {
        public int count(String table) { return jdbc.queryForObject("select count(*) from " + table, Integer.class); }
        @Override public void close() { dataSource.close(); }
    }
}
