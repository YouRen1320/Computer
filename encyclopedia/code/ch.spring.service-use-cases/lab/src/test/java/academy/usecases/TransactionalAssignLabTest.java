package academy.usecases;

import academy.usecases.TransactionalAssignLab.*;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.springframework.aop.support.AopUtils;
import static org.assertj.core.api.Assertions.*;

class TransactionalAssignLabTest {
    @Test void applicationServiceIsRealSpringProxy(){try(var f=open(false,false)){assertThat(AopUtils.isCglibProxy(f.service())).isTrue();}}
    @Test void successCommitsAggregateAuditAndOutbox(){try(var f=open(false,false)){f.service().assign(command(0));assertThat(state(f)).isEqualTo("ASSIGNED:1");assertThat(count(f,"audit_log")).isOne();assertThat(count(f,"outbox_event")).isOne();}}
    @Test void orchestrationOrderIsObservable(){try(var f=open(false,false)){f.service().assign(command(0));assertThat(f.store().events()).containsExactly("load","save","audit","outbox");}}
    @Test void everyPortRunsInsideUpperTransaction(){try(var f=open(false,false)){f.service().assign(command(0));assertThat(f.store().transactionActive()).containsOnly(true);}}
    @Test void auditFailureRollsBackAggregateAndAllSideEffects(){try(var f=open(true,false)){assertThatThrownBy(()->f.service().assign(command(0))).hasMessage("audit unavailable");assertThat(state(f)).isEqualTo("TRIAGED:0");assertThat(count(f,"audit_log")).isZero();assertThat(count(f,"outbox_event")).isZero();}}
    @Test void outboxFailureRollsBackAggregateAndAudit(){try(var f=open(false,true)){assertThatThrownBy(()->f.service().assign(command(0))).hasMessage("outbox unavailable");assertThat(state(f)).isEqualTo("TRIAGED:0");assertThat(count(f,"audit_log")).isZero();assertThat(count(f,"outbox_event")).isZero();}}
    @Test void staleVersionWritesNothing(){try(var f=open(false,false)){assertThatThrownBy(()->f.service().assign(command(9))).isInstanceOf(VersionConflict.class);assertThat(state(f)).isEqualTo("TRIAGED:0");assertThat(count(f,"audit_log")).isZero();}}
    @Test void invalidDomainStateWritesNothing(){try(var f=open(false,false)){f.jdbc().update("update work_order set state='ASSIGNED' where id='wo-1'");assertThatThrownBy(()->f.service().assign(command(0))).isInstanceOf(InvalidState.class);assertThat(count(f,"audit_log")).isZero();assertThat(count(f,"outbox_event")).isZero();}}
    @Test void successReturnsUseCaseResult(){try(var f=open(false,false)){assertThat(f.service().assign(command(0))).isEqualTo(new Result("wo-1","ASSIGNED",1));}}
    @Test void serviceDependsOnPortNotJdbcAdapter(){assertThat(AssignService.class.getDeclaredFields()).extracting(java.lang.reflect.Field::getType).containsExactly(Store.class);}
    private static Fixture open(boolean audit,boolean outbox){return TransactionalAssignLab.open("uc"+UUID.randomUUID().toString().replace("-",""),audit,outbox);} private static Command command(long v){return new Command("tenant-a","actor-a","wo-1","team-a","tech-a",v);} private static int count(Fixture f,String table){return f.jdbc().queryForObject("select count(*) from "+table,Integer.class);} private static String state(Fixture f){return f.jdbc().queryForObject("select state || ':' || version from work_order where id='wo-1'",String.class);}
}
