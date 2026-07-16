package academy.datasource;

import com.zaxxer.hikari.HikariConfig;
import com.zaxxer.hikari.HikariDataSource;
import java.sql.SQLException;
import java.util.ArrayList;
import java.util.List;

/** Owns the observable pool fixture and the migration/readiness startup gate. */
public final class PoolHarness {
    private PoolHarness() {}

    public static HikariDataSource newPool(String name, int maximumPoolSize, long connectionTimeoutMs) {
        HikariConfig config = new HikariConfig();
        config.setPoolName(name);
        config.setJdbcUrl("jdbc:h2:mem:" + name + ";DB_CLOSE_DELAY=-1");
        config.setUsername("sa");
        config.setPassword("");
        config.setMaximumPoolSize(maximumPoolSize);
        config.setMinimumIdle(0);
        config.setConnectionTimeout(connectionTimeoutMs);
        config.setValidationTimeout(250);
        config.setInitializationFailTimeout(1_000);
        return new HikariDataSource(config);
    }

    public static int borrowAndReturn(HikariDataSource dataSource) throws SQLException {
        try (var connection = dataSource.getConnection();
             var statement = connection.prepareStatement("select 1");
             var result = statement.executeQuery()) {
            if (!result.next()) throw new SQLException("probe returned no row");
            return result.getInt(1);
        }
    }

    public static final class StartupGate {
        private final HikariDataSource dataSource;
        private final String migrationSql;
        private final List<String> events = new ArrayList<>();
        private boolean migrationComplete;
        private boolean ready;

        public StartupGate(HikariDataSource dataSource) {
            this(dataSource, "create table if not exists work_order (id varchar(64) primary key)");
        }

        public StartupGate(HikariDataSource dataSource, String migrationSql) {
            this.dataSource = dataSource;
            this.migrationSql = migrationSql;
        }

        public void start() throws SQLException {
            events.add("migration");
            try (var connection = dataSource.getConnection(); var statement = connection.createStatement()) {
                statement.execute(migrationSql);
                migrationComplete = true;
            } catch (SQLException failure) {
                ready = false;
                throw failure;
            }
            refreshReadiness();
        }

        public boolean refreshReadiness() {
            events.add("readiness");
            if (!migrationComplete) return ready = false;
            try (var connection = dataSource.getConnection(); var statement = connection.createStatement()) {
                statement.executeQuery("select count(*) from work_order").close();
                return ready = true;
            } catch (SQLException failure) {
                return ready = false;
            }
        }

        public int acceptTraffic() throws SQLException {
            if (!ready) throw new IllegalStateException("database is not ready");
            events.add("traffic");
            try (var connection = dataSource.getConnection(); var statement = connection.createStatement();
                 var result = statement.executeQuery("select count(*) from work_order")) {
                result.next();
                return result.getInt(1);
            }
        }

        public boolean isReady() { return ready; }
        public List<String> events() { return List.copyOf(events); }
    }
}
