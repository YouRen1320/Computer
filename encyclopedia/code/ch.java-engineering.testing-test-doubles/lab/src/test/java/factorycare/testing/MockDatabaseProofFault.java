package factorycare.testing;

import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import java.time.Clock;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.concurrent.atomic.AtomicInteger;
import org.junit.jupiter.api.Test;

final class MockDatabaseProofFault {
    @Test
    void mockCannotProveARealUniqueConstraint() {
        var repository = mock(DispatchService.Repository.class);
        when(repository.existsBySourceKey(anyString())).thenReturn(false);
        var counter = new AtomicInteger();
        var service = new DispatchService(
                repository,
                (recipient, message) -> { },
                Clock.fixed(Instant.parse("2026-07-17T04:00:00Z"), ZoneOffset.UTC),
                () -> "D-" + counter.incrementAndGet());
        var command = new DispatchService.Command("same-source", "tech-2", 3);

        service.create(command);

        assertThrows(
                IllegalStateException.class,
                () -> service.create(command),
                "a configured mock did not execute a database unique constraint");
    }
}
