package factorycare.challenge;

import java.util.Objects;

/**
 * Small SUT whose repository and notification ports are completed in test fixtures.
 */
public final class NotificationChallenge {
    private final Repository repository;
    private final NotificationSender notifications;

    public NotificationChallenge(Repository repository, NotificationSender notifications) {
        this.repository = Objects.requireNonNull(repository, "repository");
        this.notifications = Objects.requireNonNull(notifications, "notifications");
    }

    public WorkOrder create(String id, String assigneeId, int priority) {
        var workOrder = new WorkOrder(id, assigneeId, priority);
        repository.save(workOrder);
        notifications.send(assigneeId, "created:" + id);
        return workOrder;
    }

    public interface Repository {
        void save(WorkOrder workOrder);

        WorkOrder find(String id);
    }

    @FunctionalInterface
    public interface NotificationSender {
        void send(String recipientId, String message);
    }

    public record WorkOrder(String id, String assigneeId, int priority) {
        public WorkOrder {
            id = requireText(id, "id");
            assigneeId = requireText(assigneeId, "assigneeId");
            if (priority < 1 || priority > 5) {
                throw new IllegalArgumentException("priority must be between 1 and 5");
            }
        }
    }

    private static String requireText(String value, String name) {
        Objects.requireNonNull(value, name);
        if (value.isBlank()) {
            throw new IllegalArgumentException(name + " must not be blank");
        }
        return value;
    }
}
