package factorycare.testing;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;

import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.stream.Stream;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.Arguments;
import org.junit.jupiter.params.provider.MethodSource;

final class DispatchServiceBehaviorTest {
    private static final Instant NOW = Instant.parse("2026-07-17T04:00:00Z");

    @ParameterizedTest(name = "priority {0} has SLA {1}")
    @MethodSource("slaCases")
    void computesSlaFromBoundaryCases(int priority, Duration expectedSla) {
        var fixture = newFixture();

        var actual = fixture.service().create(
                new DispatchService.Command("source-" + priority, "tech-7", priority));

        assertEquals(expectedSla, Duration.between(actual.createdAt(), actual.dueAt()));
        assertEquals(actual, fixture.repository().find(actual.id()));
    }

    @Test
    void spyCapturesTheBusinessMessageWithoutMockingValueObjects() {
        var fixture = newFixture();

        var actual = fixture.service().create(
                new DispatchService.Command("source-spy", "tech-8", 5));

        assertEquals(1, fixture.notifications().messages().size());
        assertEquals(
                "tech-8|dispatch:" + actual.id() + ":due:2026-07-17T05:00:00Z",
                fixture.notifications().messages().getFirst());
    }

    @Test
    void duplicateUsesStateOracleAndEmitsNoNewMessage() {
        var fixture = newFixture();
        fixture.repository().seed(new DispatchService.Dispatch(
                "D-OLD",
                "source-duplicate",
                "tech-1",
                1,
                NOW,
                NOW.plus(Duration.ofHours(8))));

        var error = assertThrows(
                IllegalStateException.class,
                () -> fixture.service().create(
                        new DispatchService.Command("source-duplicate", "tech-9", 4)));

        assertEquals("duplicate source key: source-duplicate", error.getMessage());
        assertEquals(List.of(), fixture.notifications().messages());
    }

    @Test
    void mockitoVerifiesOnlyTheRequiredExternalBoundary() {
        var repository = new FakeRepository();
        var notifications = mock(DispatchService.NotificationSender.class);
        var service = new DispatchService(
                repository,
                notifications,
                Clock.fixed(NOW, ZoneOffset.UTC),
                () -> "D-200");

        var actual = service.create(
                new DispatchService.Command("source-mock", "tech-10", 3));

        assertEquals(actual, repository.find("D-200"));
        verify(notifications).send(
                "tech-10",
                "dispatch:D-200:due:2026-07-17T08:00:00Z");
        verify(notifications, never()).send("tech-10", "implementation-step");
    }

    @Test
    void everyFixtureStartsEmpty() {
        assertEquals(0, newFixture().repository().size());
        assertEquals(0, newFixture().repository().size());
    }

    private static Stream<Arguments> slaCases() {
        return Stream.of(
                Arguments.of(1, Duration.ofHours(8)),
                Arguments.of(3, Duration.ofHours(4)),
                Arguments.of(4, Duration.ofHours(1)),
                Arguments.of(5, Duration.ofHours(1)));
    }

    private static Fixture newFixture() {
        var repository = new FakeRepository();
        var notifications = new SpyNotificationSender();
        var service = new DispatchService(
                repository,
                notifications,
                Clock.fixed(NOW, ZoneOffset.UTC),
                () -> "D-100");
        return new Fixture(service, repository, notifications);
    }

    private record Fixture(
            DispatchService service,
            FakeRepository repository,
            SpyNotificationSender notifications) {
    }

    static final class FakeRepository implements DispatchService.Repository {
        private final Map<String, DispatchService.Dispatch> byId = new LinkedHashMap<>();

        @Override
        public boolean existsBySourceKey(String sourceKey) {
            return byId.values().stream()
                    .anyMatch(dispatch -> dispatch.sourceKey().equals(sourceKey));
        }

        @Override
        public void save(DispatchService.Dispatch dispatch) {
            byId.put(dispatch.id(), dispatch);
        }

        DispatchService.Dispatch find(String id) {
            return byId.get(id);
        }

        void seed(DispatchService.Dispatch dispatch) {
            save(dispatch);
        }

        int size() {
            return byId.size();
        }
    }

    static final class SpyNotificationSender implements DispatchService.NotificationSender {
        private final List<String> messages = new ArrayList<>();

        @Override
        public void send(String recipientId, String message) {
            messages.add(recipientId + "|" + message);
        }

        List<String> messages() {
            return List.copyOf(messages);
        }
    }
}
