package academy.domain;

import static academy.domain.DomainFixtures.WorkOrderStatus.ACCEPTED;
import static academy.domain.DomainFixtures.WorkOrderStatus.ASSIGNED;
import static academy.domain.DomainFixtures.WorkOrderStatus.CLOSED;
import static academy.domain.DomainFixtures.WorkOrderStatus.CREATED;
import static academy.domain.DomainFixtures.WorkOrderStatus.IN_PROGRESS;
import static academy.domain.DomainFixtures.WorkOrderStatus.RESOLVED;
import static academy.domain.DomainFixtures.WorkOrderStatus.TRIAGED;
import static academy.domain.DomainFixtures.WorkOrderStatus.VERIFIED;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotEquals;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.lang.reflect.Modifier;
import java.util.Arrays;
import java.util.UUID;

import org.junit.jupiter.api.Test;

class DomainModelingExampleTest {
    private static final UUID ID = UUID.fromString("00000000-0000-0000-0000-000000000042");

    @Test
    void workOrderIdUsesValueEquality() {
        var first = new DomainFixtures.WorkOrderId(ID);
        var second = DomainFixtures.WorkOrderId.parse(ID.toString());
        assertEquals(first, second);
        assertEquals(first.hashCode(), second.hashCode());
    }

    @Test
    void differentWorkOrderIdsAreNotEqual() {
        assertNotEquals(new DomainFixtures.WorkOrderId(ID),
                new DomainFixtures.WorkOrderId(new UUID(0, 43)));
    }

    @Test
    void assetCodeNormalizesBeforeEquality() {
        assertEquals(new DomainFixtures.AssetCode(" pump-7 "),
                new DomainFixtures.AssetCode("PUMP-7"));
    }

    @Test
    void invalidValueObjectsCannotBeCreated() {
        assertThrows(IllegalArgumentException.class, () -> new DomainFixtures.AssetCode(" "));
        assertThrows(IllegalArgumentException.class, () -> new DomainFixtures.TeamId("?"));
        assertThrows(NullPointerException.class, () -> new DomainFixtures.WorkOrderId(null));
    }

    @Test
    void workOrderIsLegalImmediatelyAfterCreation() {
        var order = fresh();
        assertEquals(CREATED, order.status());
        assertNull(order.teamId());
        assertEquals(0, order.version());
        assertEquals(new DomainFixtures.AssetCode("ASSET-7"), order.assetCode());
    }

    @Test
    void assignUsesIntentAndEstablishesTeamInvariant() {
        var order = fresh();
        order.triage();
        order.assign(new DomainFixtures.TeamId("team-a"));
        assertEquals(ASSIGNED, order.status());
        assertEquals(new DomainFixtures.TeamId("TEAM-A"), order.teamId());
        assertEquals(2, order.version());
    }

    @Test
    void mainLifecycleAdvancesOnlyThroughNamedCommands() {
        var order = fresh();
        order.triage();
        assertEquals(TRIAGED, order.status());
        order.assign(new DomainFixtures.TeamId("TEAM-A"));
        assertEquals(ASSIGNED, order.status());
        order.accept();
        assertEquals(ACCEPTED, order.status());
        order.start();
        assertEquals(IN_PROGRESS, order.status());
        order.resolve();
        assertEquals(RESOLVED, order.status());
        order.verify();
        assertEquals(VERIFIED, order.status());
        order.close();
        assertEquals(CLOSED, order.status());
        assertEquals(7, order.version());
    }

    @Test
    void illegalAssignLeavesWholeSnapshotUnchanged() {
        var order = fresh();
        var before = order.snapshot();
        var failure = assertThrows(DomainFixtures.InvalidTransition.class,
                () -> order.assign(new DomainFixtures.TeamId("TEAM-A")));
        assertEquals(DomainFixtures.Command.ASSIGN, failure.command());
        assertEquals(before, order.snapshot());
    }

    @Test
    void illegalStartLeavesWholeSnapshotUnchanged() {
        var order = fresh();
        order.triage();
        var before = order.snapshot();
        assertThrows(DomainFixtures.InvalidTransition.class, order::start);
        assertEquals(before, order.snapshot());
    }

    @Test
    void illegalCloseLeavesWholeSnapshotUnchanged() {
        var order = fresh();
        order.triage();
        order.assign(new DomainFixtures.TeamId("TEAM-A"));
        order.accept();
        order.start();
        var before = order.snapshot();
        assertThrows(DomainFixtures.InvalidTransition.class, order::close);
        assertEquals(before, order.snapshot());
    }

    @Test
    void entityEqualityUsesStableIdentityAndNoPublicSetterExists() {
        var first = fresh();
        var sameIdentity = DomainFixtures.WorkOrder.create(
                new DomainFixtures.WorkOrderId(ID), new DomainFixtures.AssetCode("OTHER-9"));
        assertEquals(first, sameIdentity);
        assertEquals(first.hashCode(), sameIdentity.hashCode());
        assertTrue(Arrays.stream(DomainFixtures.WorkOrder.class.getDeclaredMethods())
                .filter(method -> Modifier.isPublic(method.getModifiers()))
                .noneMatch(method -> method.getName().startsWith("set")));
    }

    private static DomainFixtures.WorkOrder fresh() {
        return DomainFixtures.WorkOrder.create(
                new DomainFixtures.WorkOrderId(ID),
                new DomainFixtures.AssetCode("ASSET-7"));
    }
}
