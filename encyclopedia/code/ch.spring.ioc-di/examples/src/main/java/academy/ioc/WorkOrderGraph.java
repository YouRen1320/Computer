package academy.ioc;

import java.util.ArrayList;
import java.util.List;
import java.util.Objects;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

public final class WorkOrderGraph {
    private WorkOrderGraph() {
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

        public WorkOrderService(WorkOrderRepository repository, NotificationPort notifications) {
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

    public static final class InMemoryWorkOrderRepository implements WorkOrderRepository {
        private final List<String> savedEquipment = new ArrayList<>();

        @Override
        public void save(String equipmentId) {
            savedEquipment.add(equipmentId);
        }

        public List<String> savedEquipment() {
            return List.copyOf(savedEquipment);
        }
    }

    public static final class RecordingNotificationPort implements NotificationPort {
        private final List<String> messages = new ArrayList<>();

        @Override
        public void send(String message) {
            messages.add(message);
        }

        public List<String> messages() {
            return List.copyOf(messages);
        }
    }

    /**
     * Bean method parameters make graph edges explicit without calling another bean method.
     */
    @Configuration(proxyBeanMethods = false)
    public static class AppConfig {
        @Bean
        WorkOrderRepository workOrderRepository() {
            return new InMemoryWorkOrderRepository();
        }

        @Bean
        NotificationPort notificationPort() {
            return new RecordingNotificationPort();
        }

        @Bean
        WorkOrderService workOrderService(
                WorkOrderRepository repository, NotificationPort notifications) {
            return new WorkOrderService(repository, notifications);
        }
    }
}
