package academy.datasource;

import com.zaxxer.hikari.HikariConfig;
import com.zaxxer.hikari.HikariDataSource;
import java.sql.SQLException;
import java.util.ArrayList;
import java.util.List;

/** Exposes only the pool and startup observations required by the lab rubric. */
public final class PoolLab implements AutoCloseable {
    private final HikariDataSource dataSource;
    private final List<String> events = new ArrayList<>();
    private boolean migrated;
    private boolean ready;

    public PoolLab(String name, int maximum, long timeoutMs) {
        var config = new HikariConfig();
        config.setJdbcUrl("jdbc:h2:mem:" + name + ";DB_CLOSE_DELAY=-1");
        config.setUsername("sa");
        config.setMaximumPoolSize(maximum);
        config.setMinimumIdle(0);
        config.setConnectionTimeout(timeoutMs);
        config.setValidationTimeout(250);
        config.setInitializationFailTimeout(1_000);
        dataSource = new HikariDataSource(config);
    }

    public void migrate(String sql) throws SQLException {
        events.add("migration");
        try (var connection = dataSource.getConnection(); var statement = connection.createStatement()) {
            statement.execute(sql);
            migrated = true;
        } catch (SQLException failure) {
            ready = false;
            throw failure;
        }
    }

    public boolean probe() {
        events.add("readiness");
        if (!migrated) return ready = false;
        try (var connection = dataSource.getConnection(); var statement = connection.createStatement()) {
            statement.executeQuery("select count(*) from work_order").close();
            return ready = true;
        } catch (SQLException failure) {
            return ready = false;
        }
    }

    public int query() throws SQLException {
        if (!ready) throw new IllegalStateException("not ready");
        events.add("traffic");
        try (var connection = dataSource.getConnection(); var statement = connection.createStatement(); var rows = statement.executeQuery("select count(*) from work_order")) {
            rows.next();
            return rows.getInt(1);
        }
    }

    public HikariDataSource dataSource() { return dataSource; }
    public List<String> events() { return List.copyOf(events); }
    public boolean isReady() { return ready; }
    @Override public void close() { dataSource.close(); }
}
