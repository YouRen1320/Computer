package academy.ioc;

import java.util.Objects;

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
        private final WorkOrderRepository repository;
        private final NotificationPort notifications;

        public WorkOrderService(
                WorkOrderRepository repository, NotificationPort notifications) {
            this.repository = Objects.requireNonNull(repository);
            this.notifications = Objects.requireNonNull(notifications);
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
}
