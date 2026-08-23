package academy.datasource;

import java.sql.SQLTransientConnectionException;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.Executors;
import java.util.concurrent.TimeUnit;
import org.junit.jupiter.api.Test;
import static org.assertj.core.api.Assertions.*;

class PoolLabTest {
    private static final String MIGRATION = "create table if not exists work_order (id varchar(64) primary key)";

    @Test void configuredMaximumIsObservable() { try (var lab = new PoolLab("max", 2, 250)) { assertThat(lab.dataSource().getMaximumPoolSize()).isEqualTo(2); } }

    @Test void borrowIncrementsActive() throws Exception {
        try (var lab = new PoolLab("active", 1, 250); var connection = lab.dataSource().getConnection()) {
            assertThat(lab.dataSource().getHikariPoolMXBean().getActiveConnections()).isOne();
        }
    }

    @Test void closeReturnsConnection() throws Exception {
        try (var lab = new PoolLab("return", 1, 250)) {
            try (var ignored = lab.dataSource().getConnection()) { assertThat(ignored.isValid(1)).isTrue(); }
            assertThat(lab.dataSource().getHikariPoolMXBean().getActiveConnections()).isZero();
        }
    }

    @Test void concurrentBorrowAndReturnEndsAtZero() throws Exception {
        try (var lab = new PoolLab("concurrentLab", 2, 500); var executor = Executors.newFixedThreadPool(2)) {
            var acquired = new CountDownLatch(2); var release = new CountDownLatch(1);
            var a = executor.submit(() -> hold(lab, acquired, release)); var b = executor.submit(() -> hold(lab, acquired, release));
            assertThat(acquired.await(2, TimeUnit.SECONDS)).isTrue(); release.countDown(); a.get(); b.get();
            assertThat(lab.dataSource().getHikariPoolMXBean().getActiveConnections()).isZero();
        }
    }

    @Test void exhaustionTimesOut() throws Exception {
        try (var lab = new PoolLab("timeout", 1, 250); var held = lab.dataSource().getConnection()) {
            assertThatThrownBy(lab.dataSource()::getConnection).isInstanceOf(SQLTransientConnectionException.class);
        }
    }

    @Test void trafficBeforeMigrationIsRejected() { try (var lab = new PoolLab("closedGate", 1, 250)) { assertThatThrownBy(lab::query).isInstanceOf(IllegalStateException.class); } }

    @Test void migrationPrecedesReadinessAndTraffic() throws Exception {
        try (var lab = new PoolLab("ordered", 1, 250)) { lab.migrate(MIGRATION); assertThat(lab.probe()).isTrue(); assertThat(lab.query()).isZero(); assertThat(lab.events()).containsExactly("migration", "readiness", "traffic"); }
    }

    @Test void invalidMigrationKeepsGateClosed() {
        try (var lab = new PoolLab("invalid", 1, 250)) { assertThatThrownBy(() -> lab.migrate("create table broken (")).isInstanceOf(java.sql.SQLException.class); assertThat(lab.isReady()).isFalse(); }
    }

    @Test void unavailableDatabaseMakesReadinessFalse() throws Exception {
        var lab = new PoolLab("down", 1, 250); lab.migrate(MIGRATION); assertThat(lab.probe()).isTrue(); lab.dataSource().close(); assertThat(lab.probe()).isFalse(); assertThat(lab.isReady()).isFalse();
    }

    @Test void reusablePoolServesSequentialRequests() throws Exception {
        try (var lab = new PoolLab("reuse", 1, 250)) { try (var a = lab.dataSource().getConnection()) { assertThat(a.isValid(1)).isTrue(); } try (var b = lab.dataSource().getConnection()) { assertThat(b.isValid(1)).isTrue(); } assertThat(lab.dataSource().getHikariPoolMXBean().getActiveConnections()).isZero(); }
    }

    private static int hold(PoolLab lab, CountDownLatch acquired, CountDownLatch release) throws Exception { try (var connection = lab.dataSource().getConnection()) { acquired.countDown(); release.await(); return 1; } }
}
