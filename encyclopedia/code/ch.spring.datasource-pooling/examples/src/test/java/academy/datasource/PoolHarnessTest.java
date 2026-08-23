package academy.datasource;

import com.zaxxer.hikari.HikariDataSource;
import java.sql.SQLTransientConnectionException;
import java.time.Duration;
import java.util.List;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.Executors;
import org.junit.jupiter.api.Test;
import static org.assertj.core.api.Assertions.*;

class PoolHarnessTest {
    @Test void bootManagedDependencyProvidesHikari() {
        try (var pool = PoolHarness.newPool("actualHikari", 2, 250)) {
            assertThat(pool).isInstanceOf(HikariDataSource.class);
            assertThat(pool.getMaximumPoolSize()).isEqualTo(2);
        }
    }

    @Test void borrowAndReturnLeavesNoActiveConnection() throws Exception {
        try (var pool = PoolHarness.newPool("borrowReturn", 1, 250)) {
            assertThat(PoolHarness.borrowAndReturn(pool)).isOne();
            assertThat(pool.getHikariPoolMXBean().getActiveConnections()).isZero();
        }
    }

    @Test void concurrentBorrowersReturnEverything() throws Exception {
        try (var pool = PoolHarness.newPool("concurrent", 2, 500); var workers = Executors.newFixedThreadPool(2)) {
            var acquired = new CountDownLatch(2);
            var release = new CountDownLatch(1);
            var first = workers.submit(() -> borrowUntilReleased(pool, acquired, release));
            var second = workers.submit(() -> borrowUntilReleased(pool, acquired, release));
            assertThat(acquired.await(2, java.util.concurrent.TimeUnit.SECONDS)).isTrue();
            assertThat(pool.getHikariPoolMXBean().getActiveConnections()).isEqualTo(2);
            release.countDown();
            first.get(); second.get();
            assertThat(pool.getHikariPoolMXBean().getActiveConnections()).isZero();
        }
    }

    @Test void exhaustionFailsWithinConnectionTimeout() throws Exception {
        try (var pool = PoolHarness.newPool("exhaustion", 1, 250); var held = pool.getConnection()) {
            assertThatThrownBy(pool::getConnection).isInstanceOf(SQLTransientConnectionException.class);
        }
    }

    @Test void migrationCompletesBeforeTraffic() throws Exception {
        try (var pool = PoolHarness.newPool("startup", 1, 250)) {
            var gate = new PoolHarness.StartupGate(pool);
            gate.start();
            assertThat(gate.acceptTraffic()).isZero();
            assertThat(gate.events()).containsExactly("migration", "readiness", "traffic");
        }
    }

    @Test void trafficIsRejectedBeforeMigration() {
        try (var pool = PoolHarness.newPool("beforeMigration", 1, 250)) {
            var gate = new PoolHarness.StartupGate(pool);
            assertThatThrownBy(gate::acceptTraffic).isInstanceOf(IllegalStateException.class);
        }
    }

    @Test void migrationFailureKeepsReadinessFalse() {
        try (var pool = PoolHarness.newPool("badMigration", 1, 250)) {
            var gate = new PoolHarness.StartupGate(pool, "create table broken (");
            assertThatThrownBy(gate::start).isInstanceOf(java.sql.SQLException.class);
            assertThat(gate.isReady()).isFalse();
        }
    }

    @Test void unavailableDatabaseMakesReadinessFalse() throws Exception {
        var pool = PoolHarness.newPool("unavailable", 1, 250);
        var gate = new PoolHarness.StartupGate(pool);
        gate.start();
        pool.close();
        assertThat(gate.refreshReadiness()).isFalse();
        assertThat(gate.isReady()).isFalse();
    }

    private static int borrowUntilReleased(HikariDataSource pool, CountDownLatch acquired, CountDownLatch release) throws Exception {
        try (var connection = pool.getConnection()) {
            acquired.countDown();
            release.await();
            return connection.isValid(1) ? 1 : 0;
        }
    }
}
