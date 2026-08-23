package factorycare.challenge;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;

import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;

final class NotificationChallengeSolutionTest {
    @ParameterizedTest
    @ValueSource(ints = {0, 6})
    void rejectsPrioritiesOutsideTheContract(int invalidPriority) {
        var challenge = new NotificationChallenge(new FakeRepository(), (to, message) -> { });

        assertThrows(
                IllegalArgumentException.class,
                () -> challenge.create("WO-invalid", "tech-1", invalidPriority));
    }

    @Test
    void fakePersistsObservableState() {
        var repository = new FakeRepository();
        var challenge = new NotificationChallenge(repository, (to, message) -> { });

        var created = challenge.create("WO-7", "tech-7", 4);

        assertNotNull(repository.find("WO-7"));
        assertEquals(created, repository.find("WO-7"));
    }

    @Test
    void spyCapturesTheRequiredNotification() {
        var notifications = new SpyNotificationSender();
        var challenge = new NotificationChallenge(new FakeRepository(), notifications);

        challenge.create("WO-8", "tech-8", 3);

        assertEquals(List.of("tech-8|created:WO-8"), notifications.messages());
    }

    @Test
    void mockitoVerifiesOnlyTheExternalMessageContract() {
        var notifications = mock(NotificationChallenge.NotificationSender.class);
        var challenge = new NotificationChallenge(new FakeRepository(), notifications);

        challenge.create("WO-9", "tech-9", 5);

        verify(notifications).send("tech-9", "created:WO-9");
    }

    private static final class FakeRepository implements NotificationChallenge.Repository {
        private final Map<String, NotificationChallenge.WorkOrder> byId = new LinkedHashMap<>();

        @Override
        public void save(NotificationChallenge.WorkOrder workOrder) {
            byId.put(workOrder.id(), workOrder);
        }

        @Override
        public NotificationChallenge.WorkOrder find(String id) {
            return byId.get(id);
        }
    }

    private static final class SpyNotificationSender
            implements NotificationChallenge.NotificationSender {
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
