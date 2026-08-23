package academy.datasource;

import com.zaxxer.hikari.HikariConfig;
import com.zaxxer.hikari.HikariDataSource;
import org.junit.jupiter.api.Test;
import static org.assertj.core.api.Assertions.assertThat;

class ConnectionBorrowerTest {
    @Test void returnedConnectionLeavesActiveAtZero() throws Exception {
        try (var pool = pool("red")) {
            assertThat(new ConnectionBorrower(pool).selectOne()).isOne();
            assertThat(pool.getHikariPoolMXBean().getActiveConnections())
                    .as("EXPECTED_CONNECTION_RETURNED")
                    .isZero();
        }
    }

    @Test void fixtureHasNoSpareConnectionToHideLeak() {
        try (var pool = pool("bounded")) { assertThat(pool.getMaximumPoolSize()).isOne(); }
    }

    private static HikariDataSource pool(String name) {
        var config = new HikariConfig();
        config.setJdbcUrl("jdbc:h2:mem:" + name + ";DB_CLOSE_DELAY=-1");
        config.setUsername("sa");
        config.setMaximumPoolSize(1);
        config.setMinimumIdle(0);
        config.setConnectionTimeout(250);
        config.setInitializationFailTimeout(1_000);
        return new HikariDataSource(config);
    }
}
