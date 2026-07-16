package academy.ioc;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertSame;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.junit.jupiter.api.Assertions.assertThrows;

import academy.ioc.WorkOrderGraph.InMemoryWorkOrderRepository;
import academy.ioc.WorkOrderGraph.NotificationPort;
import academy.ioc.WorkOrderGraph.RecordingNotificationPort;
import academy.ioc.WorkOrderGraph.WorkOrderRepository;
import academy.ioc.WorkOrderGraph.WorkOrderService;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.BeanCurrentlyInCreationException;
import org.springframework.beans.factory.NoSuchBeanDefinitionException;
import org.springframework.beans.factory.NoUniqueBeanDefinitionException;
import org.springframework.context.annotation.AnnotationConfigApplicationContext;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

class WorkOrderGraphTest {
    @Test
    void manualCompositionBuildsTheSameExplicitObjectGraph() {
        var repository = new InMemoryWorkOrderRepository();
        var notifications = new RecordingNotificationPort();
        var service = new WorkOrderService(repository, notifications);

        assertEquals("opened:EQ-1", service.open("EQ-1"));
        assertEquals(List.of("EQ-1"), repository.savedEquipment());
        assertEquals(List.of("opened:EQ-1"), notifications.messages());
    }

    @Test
    void applicationContextReadsBeanDefinitionsAndResolvesConstructorEdges() {
        try (var context = new AnnotationConfigApplicationContext(WorkOrderGraph.AppConfig.class)) {
            assertTrue(Arrays.asList(context.getBeanDefinitionNames()).containsAll(
                    List.of("workOrderRepository", "notificationPort", "workOrderService")));

            WorkOrderService service = context.getBean(WorkOrderService.class);
            var repository = (InMemoryWorkOrderRepository) context.getBean("workOrderRepository");
            var notifications = (RecordingNotificationPort) context.getBean("notificationPort");

            assertSame(service, context.getBean("workOrderService"));
            assertEquals("opened:EQ-2", service.open("EQ-2"));
            assertEquals(List.of("EQ-2"), repository.savedEquipment());
            assertEquals(List.of("opened:EQ-2"), notifications.messages());
        }
    }

    @Test
    void constructorInjectionLetsAUnitTestReplaceBothPortsWithoutSpring() {
        List<String> saved = new ArrayList<>();
        List<String> sent = new ArrayList<>();
        WorkOrderRepository repository = saved::add;
        NotificationPort notifications = sent::add;

        var service = new WorkOrderService(repository, notifications);

        assertEquals("opened:EQ-test", service.open("EQ-test"));
        assertEquals(List.of("EQ-test"), saved);
        assertEquals(List.of("opened:EQ-test"), sent);
    }

    @Test
    void testConfigurationReplacesTheNotificationImplementation() {
        try (var context = new AnnotationConfigApplicationContext(TestReplacementConfig.class)) {
            WorkOrderService service = context.getBean(WorkOrderService.class);
            var repository = context.getBean(TestRepository.class);
            var notifications = context.getBean(SpyNotificationPort.class);

            assertEquals("opened:EQ-config", service.open("EQ-config"));
            assertEquals(List.of("EQ-config"), repository.saved());
            assertEquals(List.of("opened:EQ-config"), notifications.messages());
        }
    }

    @Test
    void missingRequiredBeanFailsDuringContextRefresh() {
        assertRefreshFailureHasCause(MissingRepositoryConfig.class, NoSuchBeanDefinitionException.class);
    }

    @Test
    void twoBeansOfTheSameRequiredTypeAreAmbiguous() {
        assertRefreshFailureHasCause(AmbiguousNotificationConfig.class, NoUniqueBeanDefinitionException.class);
    }

    @Test
    void constructorCycleFailsInsteadOfProducingHalfInitializedObjects() {
        assertRefreshFailureHasCause(ConstructorCycleConfig.class, BeanCurrentlyInCreationException.class);
    }

    private static void assertRefreshFailureHasCause(
            Class<?> configClass, Class<? extends Throwable> expectedCause) {
        try (var context = new AnnotationConfigApplicationContext()) {
            context.register(configClass);
            RuntimeException failure = assertThrows(RuntimeException.class, context::refresh);
            assertTrue(hasCause(failure, expectedCause),
                    () -> "EXPECTED_CAUSE " + expectedCause.getSimpleName() + " but got " + failure);
        }
    }

    private static boolean hasCause(Throwable failure, Class<? extends Throwable> expected) {
        for (Throwable current = failure; current != null; current = current.getCause()) {
            if (expected.isInstance(current)) {
                return true;
            }
        }
        return false;
    }

    static final class TestRepository implements WorkOrderRepository {
        private final List<String> saved = new ArrayList<>();

        @Override
        public void save(String equipmentId) {
            saved.add(equipmentId);
        }

        List<String> saved() {
            return List.copyOf(saved);
        }
    }

    static final class SpyNotificationPort implements NotificationPort {
        private final List<String> messages = new ArrayList<>();

        @Override
        public void send(String message) {
            messages.add(message);
        }

        List<String> messages() {
            return List.copyOf(messages);
        }
    }

    @Configuration(proxyBeanMethods = false)
    static class TestReplacementConfig {
        @Bean
        TestRepository workOrderRepository() {
            return new TestRepository();
        }

        @Bean
        SpyNotificationPort notificationPort() {
            return new SpyNotificationPort();
        }

        @Bean
        WorkOrderService workOrderService(
                WorkOrderRepository repository, NotificationPort notificationPort) {
            return new WorkOrderService(repository, notificationPort);
        }
    }

    @Configuration(proxyBeanMethods = false)
    static class MissingRepositoryConfig {
        @Bean
        NotificationPort notificationPort() {
            return message -> {
            };
        }

        @Bean
        WorkOrderService workOrderService(
                WorkOrderRepository repository, NotificationPort notificationPort) {
            return new WorkOrderService(repository, notificationPort);
        }
    }

    @Configuration(proxyBeanMethods = false)
    static class AmbiguousNotificationConfig {
        @Bean
        WorkOrderRepository workOrderRepository() {
            return equipmentId -> {
            };
        }

        @Bean
        NotificationPort emailNotification() {
            return message -> {
            };
        }

        @Bean
        NotificationPort auditNotification() {
            return message -> {
            };
        }

        @Bean
        WorkOrderService workOrderService(
                WorkOrderRepository repository, NotificationPort notificationPort) {
            return new WorkOrderService(repository, notificationPort);
        }
    }

    static final class CycleA {
        CycleA(CycleB dependency) {
        }
    }

    static final class CycleB {
        CycleB(CycleA dependency) {
        }
    }

    @Configuration(proxyBeanMethods = false)
    static class ConstructorCycleConfig {
        @Bean
        CycleA cycleA(CycleB dependency) {
            return new CycleA(dependency);
        }

        @Bean
        CycleB cycleB(CycleA dependency) {
            return new CycleB(dependency);
        }
    }
}
