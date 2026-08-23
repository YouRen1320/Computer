package academy.aftercommit;

import com.zaxxer.hikari.*;
import java.util.*;
import org.springframework.aop.framework.ProxyFactory;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.datasource.DataSourceTransactionManager;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.transaction.annotation.AnnotationTransactionAttributeSource;
import org.springframework.transaction.interceptor.*;

/** Starter intentionally performs an irreversible effect before the surrounding commit succeeds. */
public final class AfterCommitBoundary {
    private AfterCommitBoundary() {}
    public static class CreateService {
        private final JdbcTemplate jdbc; private final List<String> published;
        CreateService(JdbcTemplate jdbc, List<String> published) { this.jdbc = jdbc; this.published = published; }
        @Transactional public void create(String id, boolean fail) {
            jdbc.update("insert into work_order(id,status) values(?,'CREATED')", id);
            published.add(id);
            if (fail) throw new IllegalStateException("audit failed");
        }
    }
    public static Fixture open(String name) {
        var config = new HikariConfig(); config.setJdbcUrl("jdbc:h2:mem:" + name); config.setUsername("sa"); var ds = new HikariDataSource(config); var jdbc = new JdbcTemplate(ds);
        jdbc.execute("create table work_order(id varchar(64) primary key,status varchar(16))"); var published = new ArrayList<String>(); var target = new CreateService(jdbc, published);
        var factory = new ProxyFactory(target); factory.setProxyTargetClass(true); factory.addAdvice(new TransactionInterceptor(new DataSourceTransactionManager(ds), new AnnotationTransactionAttributeSource()));
        return new Fixture((CreateService) factory.getProxy(), jdbc, published, ds);
    }
    public record Fixture(CreateService service, JdbcTemplate jdbc, List<String> published, HikariDataSource dataSource) implements AutoCloseable { public int rows() { return jdbc.queryForObject("select count(*) from work_order", Integer.class); } public void close() { dataSource.close(); } }
}
