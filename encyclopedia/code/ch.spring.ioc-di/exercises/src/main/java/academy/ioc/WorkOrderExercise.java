package academy.ioc;

import java.util.ArrayList;
import java.util.List;

public final class WorkOrderExercise {
    private WorkOrderExercise() {
    }

    public interface WorkOrderRepository {
        void save(String equipmentId);
    }

    public interface NotificationPort {
        void send(String message);
    }

    public static final class WorkOrderService {
        // Deliberate starter fault: object creation is hidden inside the business service.
        private final InMemoryRepository repository = new InMemoryRepository();
        private final RecordingNotificationPort notifications = new RecordingNotificationPort();

        public WorkOrderService() {
        }

        public String open(String equipmentId) {
            if (equipmentId == null || equipmentId.isBlank()) {
                throw new IllegalArgumentException("equipmentId must not be blank");
            }
            repository.save(equipmentId);
            String event = "opened:" + equipmentId;
            notifications.send(event);
            return event;
        }
    }

    private static final class InMemoryRepository implements WorkOrderRepository {
        private final List<String> saved = new ArrayList<>();

        @Override
        public void save(String equipmentId) {
            saved.add(equipmentId);
        }
    }

    private static final class RecordingNotificationPort implements NotificationPort {
        private final List<String> messages = new ArrayList<>();

        @Override
        public void send(String message) {
            messages.add(message);
        }
    }
}
