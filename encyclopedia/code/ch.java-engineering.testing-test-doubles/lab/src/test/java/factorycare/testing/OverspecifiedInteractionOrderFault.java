package factorycare.testing;

import static org.mockito.Mockito.inOrder;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import java.time.Clock;
import java.time.Instant;
import java.time.ZoneOffset;
import org.junit.jupiter.api.Test;

final class OverspecifiedInteractionOrderFault {
    @Test
    void freezesAnOrderThatIsNotTheBusinessOracle() {
        var repository = mock(DispatchService.Repository.class);
        var notifications = mock(DispatchService.NotificationSender.class);
        when(repository.existsBySourceKey("fault-order")).thenReturn(false);
        var service = new DispatchService(
                repository,
                notifications,
                Clock.fixed(Instant.parse("2026-07-17T04:00:00Z"), ZoneOffset.UTC),
                () -> "D-FAULT");

        var dispatch = service.create(
                new DispatchService.Command("fault-order", "tech-fault", 4));

        var order = inOrder(repository, notifications);
        order.verify(notifications).send(
                "tech-fault",
                "dispatch:D-FAULT:due:" + dispatch.dueAt());
        order.verify(repository).save(dispatch);
    }
}
