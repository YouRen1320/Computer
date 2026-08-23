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

final class NotificationChallengeTest {
    @ParameterizedTest
    @ValueSource(ints = {0, 6})
    void rejectsPrioritiesOutsideTheContract(int invalidPriority) {
        var challenge = new NotificationChallenge(new CandidateFakeRepository(), (to, message) -> { });

        assertThrows(
                IllegalArgumentException.class,
                () -> challenge.create("WO-invalid", "tech-1", invalidPriority));
    }

    @Test
    void candidateFakePersistsObservableState() {
        var repository = new CandidateFakeRepository();
        var challenge = new NotificationChallenge(repository, (to, message) -> { });

        var created = challenge.create("WO-7", "tech-7", 4);

        assertNotNull(repository.find("WO-7"));
        assertEquals(created, repository.find("WO-7"));
    }

    @Test
    void candidateSpyCapturesTheRequiredNotification() {
        var notifications = new CandidateSpyNotificationSender();
        var challenge = new NotificationChallenge(new CandidateFakeRepository(), notifications);

        challenge.create("WO-8", "tech-8", 3);

        assertEquals(List.of("tech-8|created:WO-8"), notifications.messages());
    }

    @Test
    void mockitoVerifiesOnlyTheExternalMessageContract() {
        var notifications = mock(NotificationChallenge.NotificationSender.class);
        var challenge = new NotificationChallenge(new CandidateFakeRepository(), notifications);

        challenge.create("WO-9", "tech-9", 5);

        verify(notifications).send("tech-9", "created:WO-9");
    }

    private static final class CandidateFakeRepository implements NotificationChallenge.Repository {
        private final Map<String, NotificationChallenge.WorkOrder> byId = new LinkedHashMap<>();

        @Override
        public void save(NotificationChallenge.WorkOrder workOrder) {
            // TODO implement in-memory save without introducing shared static state.
        }

        @Override
        public NotificationChallenge.WorkOrder find(String id) {
            return byId.get(id);
        }
    }

    private static final class CandidateSpyNotificationSender
            implements NotificationChallenge.NotificationSender {
        private final List<String> messages = new ArrayList<>();

        @Override
        public void send(String recipientId, String message) {
            // TODO capture the business message without sending external I/O.
        }

        List<String> messages() {
            return List.copyOf(messages);
        }
    }
}
