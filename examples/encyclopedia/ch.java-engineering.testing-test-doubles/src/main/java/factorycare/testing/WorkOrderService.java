package factorycare.testing;

import java.util.Objects;

/**
 * Coordinates a deterministic work-order use case through explicit boundary ports.
 */
public final class WorkOrderService {
    private final WorkOrderRepository repository;
    private final IdGenerator ids;
    private final NotificationSender notifications;

    public WorkOrderService(
            WorkOrderRepository repository,
            IdGenerator ids,
            NotificationSender notifications) {
        this.repository = Objects.requireNonNull(repository, "repository");
        this.ids = Objects.requireNonNull(ids, "ids");
        this.notifications = Objects.requireNonNull(notifications, "notifications");
    }

    public WorkOrder create(Request request) {
        Objects.requireNonNull(request, "request");
        if (repository.existsBySourceKey(request.sourceKey())) {
            throw new IllegalStateException("duplicate source key: " + request.sourceKey());
        }

        var route = request.priority() >= 4 ? Route.URGENT : Route.STANDARD;
        var workOrder = new WorkOrder(
                ids.nextId(),
                request.sourceKey(),
                request.reporterId(),
                request.priority(),
                route);
        repository.save(workOrder);
        notifications.send(request.reporterId(), "created:" + workOrder.id());
        return workOrder;
    }

    public interface WorkOrderRepository {
        boolean existsBySourceKey(String sourceKey);

        void save(WorkOrder workOrder);
    }

    @FunctionalInterface
    public interface IdGenerator {
        String nextId();
    }

    @FunctionalInterface
    public interface NotificationSender {
        void send(String recipientId, String message);
    }

    public enum Route {
        STANDARD,
        URGENT
    }

    public record Request(String sourceKey, String reporterId, int priority) {
        public Request {
            sourceKey = requireText(sourceKey, "sourceKey");
            reporterId = requireText(reporterId, "reporterId");
            if (priority < 1 || priority > 5) {
                throw new IllegalArgumentException("priority must be between 1 and 5");
            }
        }
    }

    public record WorkOrder(
            String id,
            String sourceKey,
            String reporterId,
            int priority,
            Route route) {
        public WorkOrder {
            id = requireText(id, "id");
            sourceKey = requireText(sourceKey, "sourceKey");
            reporterId = requireText(reporterId, "reporterId");
            Objects.requireNonNull(route, "route");
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
