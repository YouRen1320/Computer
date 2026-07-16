package academy.transactions;

import com.zaxxer.hikari.*;
import java.util.*;
import org.springframework.aop.framework.ProxyFactory;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.datasource.DataSourceTransactionManager;
import org.springframework.transaction.annotation.*;
import org.springframework.transaction.interceptor.TransactionInterceptor;
import org.springframework.transaction.support.*;

/** Real Spring proxy fixture for atomic JDBC writes and post-commit side effects. */
public final class TransactionBoundary {
    private TransactionBoundary() {}
    public static class CreateService {
        private final JdbcTemplate jdbc; private final List<String> published; private final List<Boolean> active;
        CreateService(JdbcTemplate jdbc, List<String> published, List<Boolean> active) { this.jdbc = jdbc; this.published = published; this.active = active; }
        @Transactional
        public void create(String id, boolean fail) {
            active.add(TransactionSynchronizationManager.isActualTransactionActive());
            jdbc.update("insert into work_order(id,status) values(?,'OPEN')", id);
            active.add(TransactionSynchronizationManager.isActualTransactionActive());
            jdbc.update("insert into audit_log(work_order_id,action) values(?,'CREATED')", id);
            if (TransactionSynchronizationManager.isSynchronizationActive()) {
                TransactionSynchronizationManager.registerSynchronization(new TransactionSynchronization() {
                    @Override public void afterCommit() { published.add(id); }
                });
            } else {
                published.add("DIRECT:" + id);
            }
            if (fail) throw new IllegalStateException("audit pipeline failed");
        }
    }
    public static Fixture open(String name) {
        var config = new HikariConfig(); config.setJdbcUrl("jdbc:h2:mem:" + name); config.setUsername("sa"); config.setMaximumPoolSize(2);
        var dataSource = new HikariDataSource(config); var jdbc = new JdbcTemplate(dataSource);
        jdbc.execute("create table work_order(id varchar(64) primary key,status varchar(16))");
        jdbc.execute("create table audit_log(work_order_id varchar(64),action varchar(32))");
        var published = new ArrayList<String>(); var active = new ArrayList<Boolean>(); var target = new CreateService(jdbc, published, active);
        var interceptor = new TransactionInterceptor(new DataSourceTransactionManager(dataSource), new AnnotationTransactionAttributeSource());
        var factory = new ProxyFactory(target); factory.setProxyTargetClass(true); factory.addAdvice(interceptor);
        return new Fixture((CreateService) factory.getProxy(), target, jdbc, published, active, dataSource);
    }
    public record Fixture(CreateService proxy, CreateService target, JdbcTemplate jdbc, List<String> published, List<Boolean> active, HikariDataSource dataSource) implements AutoCloseable {
        public int count(String table) { return jdbc.queryForObject("select count(*) from " + table, Integer.class); }
        @Override public void close() { dataSource.close(); }
    }
}
