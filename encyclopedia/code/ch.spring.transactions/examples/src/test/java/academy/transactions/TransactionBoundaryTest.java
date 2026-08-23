package academy.transactions;

import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.springframework.aop.support.AopUtils;
import static org.assertj.core.api.Assertions.*;

class TransactionBoundaryTest {
    private static TransactionBoundary.Fixture open() { return TransactionBoundary.open("tx" + UUID.randomUUID().toString().replace("-", "")); }
    @Test void serviceEntryIsARealSpringProxy() { try (var f = open()) { assertThat(AopUtils.isCglibProxy(f.proxy())).isTrue(); } }
    @Test void successCommitsWorkOrderAndAuditTogether() { try (var f = open()) { f.proxy().create("wo-1", false); assertThat(f.count("work_order")).isOne(); assertThat(f.count("audit_log")).isOne(); } }
    @Test void runtimeFailureRollsBothTablesBack() { try (var f = open()) { assertThatThrownBy(() -> f.proxy().create("wo-1", true)).hasMessage("audit pipeline failed"); assertThat(f.count("work_order")).isZero(); assertThat(f.count("audit_log")).isZero(); } }
    @Test void successPublishesOnlyAfterCommit() { try (var f = open()) { f.proxy().create("wo-1", false); assertThat(f.published()).containsExactly("wo-1"); } }
    @Test void rollbackDoesNotPublish() { try (var f = open()) { assertThatThrownBy(() -> f.proxy().create("wo-1", true)); assertThat(f.published()).isEmpty(); } }
    @Test void repositoryWritesObserveActiveTransaction() { try (var f = open()) { f.proxy().create("wo-1", false); assertThat(f.active()).containsExactly(true, true); } }
    @Test void directTargetCallBypassesRollback() { try (var f = open()) { assertThatThrownBy(() -> f.target().create("wo-1", true)); assertThat(f.count("work_order")).isOne(); assertThat(f.count("audit_log")).isOne(); } }
    @Test void directTargetCallLeaksPreCommitSideEffect() { try (var f = open()) { assertThatThrownBy(() -> f.target().create("wo-1", true)); assertThat(f.published()).containsExactly("DIRECT:wo-1"); } }
}
