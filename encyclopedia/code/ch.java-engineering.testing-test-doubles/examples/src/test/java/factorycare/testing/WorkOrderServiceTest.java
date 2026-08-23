package factorycare.testing;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;

import java.util.LinkedHashMap;
import java.util.Map;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.CsvSource;

final class WorkOrderServiceTest {
    @ParameterizedTest(name = "priority {0} routes to {1}")
    @CsvSource({
        "1, STANDARD",
        "3, STANDARD",
        "4, URGENT",
        "5, URGENT"
    })
    void routesBoundaryPrioritiesByBehavior(int priority, WorkOrderService.Route expected) {
        var repository = new FakeRepository();
        var notifications = mock(WorkOrderService.NotificationSender.class);
        var service = new WorkOrderService(repository, () -> "WO-100", notifications);

        var actual = service.create(
                new WorkOrderService.Request("sensor-" + priority, "operator-7", priority));

        assertEquals(expected, actual.route());
        assertEquals(actual, repository.find(actual.id()));
    }

    @Test
    void persistsStateAndVerifiesOnlyTheRequiredNotification() {
        var repository = new FakeRepository();
        var notifications = mock(WorkOrderService.NotificationSender.class);
        var service = new WorkOrderService(repository, () -> "WO-101", notifications);

        var actual = service.create(
                new WorkOrderService.Request("alarm-101", "operator-8", 5));

        assertEquals("WO-101", actual.id());
        assertEquals(actual, repository.find("WO-101"));
        verify(notifications).send("operator-8", "created:WO-101");
    }

    @Test
    void rejectsDuplicateWithoutSendingNotification() {
        var repository = new FakeRepository();
        repository.seed(new WorkOrderService.WorkOrder(
                "WO-OLD",
                "alarm-duplicate",
                "operator-1",
                2,
                WorkOrderService.Route.STANDARD));
        var notifications = mock(WorkOrderService.NotificationSender.class);
        var service = new WorkOrderService(repository, () -> "WO-UNUSED", notifications);

        var error = assertThrows(
                IllegalStateException.class,
                () -> service.create(
                        new WorkOrderService.Request("alarm-duplicate", "operator-9", 4)));

        assertEquals("duplicate source key: alarm-duplicate", error.getMessage());
        verify(notifications, never()).send("operator-9", "created:WO-UNUSED");
    }

    private static final class FakeRepository implements WorkOrderService.WorkOrderRepository {
        private final Map<String, WorkOrderService.WorkOrder> byId = new LinkedHashMap<>();

        @Override
        public boolean existsBySourceKey(String sourceKey) {
            return byId.values().stream()
                    .anyMatch(workOrder -> workOrder.sourceKey().equals(sourceKey));
        }

        @Override
        public void save(WorkOrderService.WorkOrder workOrder) {
            byId.put(workOrder.id(), workOrder);
        }

        WorkOrderService.WorkOrder find(String id) {
            return byId.get(id);
        }

        void seed(WorkOrderService.WorkOrder workOrder) {
            save(workOrder);
        }
    }
}
