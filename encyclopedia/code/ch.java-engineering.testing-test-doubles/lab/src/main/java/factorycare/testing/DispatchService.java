package factorycare.testing;

import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.util.Objects;

/**
 * Applies SLA policy, persists the dispatch, then emits the required notification.
 */
public final class DispatchService {
    private final Repository repository;
    private final NotificationSender notifications;
    private final Clock clock;
    private final IdGenerator ids;

    public DispatchService(
            Repository repository,
            NotificationSender notifications,
            Clock clock,
            IdGenerator ids) {
        this.repository = Objects.requireNonNull(repository, "repository");
        this.notifications = Objects.requireNonNull(notifications, "notifications");
        this.clock = Objects.requireNonNull(clock, "clock");
        this.ids = Objects.requireNonNull(ids, "ids");
    }

    public Dispatch create(Command command) {
        Objects.requireNonNull(command, "command");
        if (repository.existsBySourceKey(command.sourceKey())) {
            throw new IllegalStateException("duplicate source key: " + command.sourceKey());
        }

        var createdAt = clock.instant();
        var dispatch = new Dispatch(
                ids.nextId(),
                command.sourceKey(),
                command.assigneeId(),
                command.priority(),
                createdAt,
                createdAt.plus(slaFor(command.priority())));
        repository.save(dispatch);
        notifications.send(
                command.assigneeId(),
                "dispatch:" + dispatch.id() + ":due:" + dispatch.dueAt());
        return dispatch;
    }

    public static Duration slaFor(int priority) {
        return switch (priority) {
            case 1, 2 -> Duration.ofHours(8);
            case 3 -> Duration.ofHours(4);
            case 4, 5 -> Duration.ofHours(1);
            default -> throw new IllegalArgumentException("priority must be between 1 and 5");
        };
    }

    public interface Repository {
        boolean existsBySourceKey(String sourceKey);

        void save(Dispatch dispatch);
    }

    @FunctionalInterface
    public interface NotificationSender {
        void send(String recipientId, String message);
    }

    @FunctionalInterface
    public interface IdGenerator {
        String nextId();
    }

    public record Command(String sourceKey, String assigneeId, int priority) {
        public Command {
            sourceKey = requireText(sourceKey, "sourceKey");
            assigneeId = requireText(assigneeId, "assigneeId");
            slaFor(priority);
        }
    }

    public record Dispatch(
            String id,
            String sourceKey,
            String assigneeId,
            int priority,
            Instant createdAt,
            Instant dueAt) {
        public Dispatch {
            id = requireText(id, "id");
            sourceKey = requireText(sourceKey, "sourceKey");
            assigneeId = requireText(assigneeId, "assigneeId");
            slaFor(priority);
            Objects.requireNonNull(createdAt, "createdAt");
            Objects.requireNonNull(dueAt, "dueAt");
            if (dueAt.isBefore(createdAt)) {
                throw new IllegalArgumentException("dueAt must not be before createdAt");
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
