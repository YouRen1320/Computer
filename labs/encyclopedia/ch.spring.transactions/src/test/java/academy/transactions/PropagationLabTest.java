package academy.transactions;

import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.springframework.aop.support.AopUtils;
import static org.assertj.core.api.Assertions.*;

class PropagationLabTest {
    private static PropagationLab.Fixture open() { return PropagationLab.open("prop" + UUID.randomUUID().toString().replace("-", "")); }
    @Test void bothCollaboratorsAreRealSpringProxies() { try (var f = open()) { assertThat(AopUtils.isCglibProxy(f.service())).isTrue(); assertThat(AopUtils.isCglibProxy(f.audit())).isTrue(); } }
    @Test void successCommitsWorkAndCoreAudit() { try (var f = open()) { f.service().success("wo-1"); assertThat(f.count("work_order")).isOne(); assertThat(f.count("audit_log")).isOne(); } }
    @Test void requiredJoinsOuterRollback() { try (var f = open()) { assertThatThrownBy(() -> f.service().requiredThenFail("wo-1")); assertThat(f.count("work_order")).isZero(); assertThat(f.count("audit_log")).isZero(); } }
    @Test void requiresNewCommitsIndependently() { try (var f = open()) { assertThatThrownBy(() -> f.service().requiresNewThenFail("wo-1")); assertThat(f.count("work_order")).isZero(); assertThat(f.count("audit_log")).isOne(); } }
    @Test void checkedExceptionCommitsByDefault() { try (var f = open()) { assertThatThrownBy(() -> f.service().checkedDefault("wo-1")).isInstanceOf(PropagationLab.CheckedFailure.class); assertThat(f.count("work_order")).isOne(); assertThat(f.count("audit_log")).isOne(); } }
    @Test void rollbackForIncludesCheckedException() { try (var f = open()) { assertThatThrownBy(() -> f.service().checkedRollback("wo-1")).isInstanceOf(PropagationLab.CheckedFailure.class); assertThat(f.count("work_order")).isZero(); assertThat(f.count("audit_log")).isZero(); } }
    @Test void callbackRunsAfterSuccessfulCommit() { try (var f = open()) { f.service().success("wo-1"); assertThat(f.published()).containsExactly("wo-1"); } }
    @Test void callbackDoesNotRunAfterRollback() { try (var f = open()) { assertThatThrownBy(() -> f.service().rollbackAfterRegistration("wo-1")); assertThat(f.published()).isEmpty(); } }
    @Test void selfInvocationDoesNotCreateIndependentTransaction() { try (var f = open()) { assertThatThrownBy(() -> f.service().selfInvocationThenFail("wo-1")); assertThat(f.count("work_order")).isZero(); assertThat(f.count("audit_log")).isZero(); } }
    @Test void innerRepositoryCallsSeeTransactions() { try (var f = open()) { f.service().success("wo-1"); assertThat(f.active()).containsExactly(true); } }
}
