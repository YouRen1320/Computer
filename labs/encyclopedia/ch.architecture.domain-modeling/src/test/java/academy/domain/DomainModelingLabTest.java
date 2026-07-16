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

import java.util.List;
import java.util.UUID;

import org.junit.jupiter.api.Test;

class DomainModelingLabTest {
    private static final UUID ID = UUID.fromString("00000000-0000-0000-0000-000000000042");

    @Test
    void statusSetMatchesFactoryCareContractExactly() {
        assertEquals(List.of("CREATED", "TRIAGED", "ASSIGNED", "ACCEPTED", "IN_PROGRESS",
                        "PENDING_PARTS", "PENDING_APPROVAL", "RESOLVED", "VERIFIED", "CLOSED",
                        "REOPENED", "CANCELLED"),
                List.of(DomainFixtures.WorkOrderStatus.values()).stream().map(Enum::name).toList());
    }

    @Test
    void workOrderIdParsesAndComparesByValue() {
        assertEquals(new DomainFixtures.WorkOrderId(ID),
                DomainFixtures.WorkOrderId.parse(ID.toString()));
        assertNotEquals(new DomainFixtures.WorkOrderId(ID),
                new DomainFixtures.WorkOrderId(new UUID(0, 99)));
    }

    @Test
    void assetAndTeamCodesHaveExplicitNormalization() {
        assertEquals(new DomainFixtures.AssetCode(" asset-7 "),
                new DomainFixtures.AssetCode("ASSET-7"));
        assertEquals(new DomainFixtures.TeamId(" team-a "),
                new DomainFixtures.TeamId("TEAM-A"));
    }

    @Test
    void invalidValueObjectsFailAtConstructionBoundary() {
        assertThrows(IllegalArgumentException.class, () -> new DomainFixtures.AssetCode("a"));
        assertThrows(IllegalArgumentException.class, () -> new DomainFixtures.TeamId("*bad*"));
        assertThrows(NullPointerException.class, () -> new DomainFixtures.WorkOrderId(null));
    }

    @Test
    void creationProducesLegalAggregateImmediately() {
        var order = fresh();
        assertEquals(CREATED, order.status());
        assertNull(order.teamId());
        assertEquals(0, order.version());
    }

    @Test
    void triageIsCreatedToTriagedOnly() {
        var order = fresh();
        order.triage();
        assertEquals(TRIAGED, order.status());
        assertEquals(1, order.version());
    }

    @Test
    void assignRequiresTriagedAndStoresTeamAsOneChange() {
        var order = fresh();
        order.triage();
        order.assign(new DomainFixtures.TeamId("TEAM-A"));
        assertEquals(new DomainFixtures.Snapshot(ASSIGNED,
                new DomainFixtures.TeamId("TEAM-A"), 2), order.snapshot());
    }

    @Test
    void fullMainPathHasSevenLegalTransitions() {
        var order = assigned();
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
    void repeatedTriageFailsWithoutChangingSnapshot() {
        var order = fresh();
        order.triage();
        var before = order.snapshot();
        assertThrows(DomainFixtures.InvalidTransition.class, order::triage);
        assertEquals(before, order.snapshot());
    }

    @Test
    void assignFromCreatedFailsWithoutPartialTeamWrite() {
        var order = fresh();
        var before = order.snapshot();
        assertThrows(DomainFixtures.InvalidTransition.class,
                () -> order.assign(new DomainFixtures.TeamId("TEAM-A")));
        assertEquals(before, order.snapshot());
    }

    @Test
    void startBeforeAcceptFailsWithoutVersionChange() {
        var order = assigned();
        var before = order.snapshot();
        assertThrows(DomainFixtures.InvalidTransition.class, order::start);
        assertEquals(before, order.snapshot());
    }

    @Test
    void closeBeforeVerifyFailsAndEntityEqualityStillUsesId() {
        var order = assigned();
        var before = order.snapshot();
        assertThrows(DomainFixtures.InvalidTransition.class, order::close);
        assertEquals(before, order.snapshot());
        var sameId = DomainFixtures.WorkOrder.create(new DomainFixtures.WorkOrderId(ID),
                new DomainFixtures.AssetCode("OTHER-9"));
        assertEquals(order, sameId);
    }

    private static DomainFixtures.WorkOrder fresh() {
        return DomainFixtures.WorkOrder.create(new DomainFixtures.WorkOrderId(ID),
                new DomainFixtures.AssetCode("ASSET-7"));
    }

    private static DomainFixtures.WorkOrder assigned() {
        var order = fresh();
        order.triage();
        order.assign(new DomainFixtures.TeamId("TEAM-A"));
        return order;
    }
}
