package academy.ioc;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

import academy.ioc.WorkOrderGraph.NotificationPort;
import academy.ioc.WorkOrderGraph.WorkOrderRepository;
import academy.ioc.WorkOrderGraph.WorkOrderService;
import java.lang.reflect.Modifier;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;
import java.util.Set;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.BeanCurrentlyInCreationException;
import org.springframework.beans.factory.NoSuchBeanDefinitionException;
import org.springframework.beans.factory.NoUniqueBeanDefinitionException;
import org.springframework.context.annotation.AnnotationConfigApplicationContext;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

class IocDependencyGraphLabTest {
    @Test
    void constructorSignaturePublishesBothRequiredGraphEdges() {
        var constructors = WorkOrderService.class.getDeclaredConstructors();
        assertEquals(1, constructors.length);
        assertEquals(
                List.of(WorkOrderRepository.class, NotificationPort.class),
                Arrays.asList(constructors[0].getParameterTypes()));

        var dependencyFields = WorkOrderService.class.getDeclaredFields();
        assertEquals(2, dependencyFields.length);
        assertTrue(Arrays.stream(dependencyFields)
                .allMatch(field -> Modifier.isFinal(field.getModifiers())));
    }

    @Test
    void pureUnitTestCanReplaceEveryOutboundPortWithoutAContainer() {
        List<String> repositoryCalls = new ArrayList<>();
        List<String> notificationCalls = new ArrayList<>();
        var service = new WorkOrderService(repositoryCalls::add, notificationCalls::add);

        assertEquals("opened:EQ-unit", service.open("EQ-unit"));
        assertEquals(List.of("EQ-unit"), repositoryCalls);
        assertEquals(List.of("opened:EQ-unit"), notificationCalls);
    }

    @Test
    void containerSmokeTestCreatesTheConfiguredRootBean() {
        try (var context = new AnnotationConfigApplicationContext(WorkOrderGraph.AppConfig.class)) {
            WorkOrderService service = context.getBean(WorkOrderService.class);

            assertNotNull(service);
            assertEquals("opened:EQ-container", service.open("EQ-container"));
        }
    }

    @Test
    void beanFactoryReportsCollaboratorsAndTheConfigurationMethodOwner() {
        try (var context = new AnnotationConfigApplicationContext(WorkOrderGraph.AppConfig.class)) {
            context.getBean("workOrderService");

            Set<String> dependencies = Set.copyOf(Arrays.asList(
                    context.getBeanFactory().getDependenciesForBean("workOrderService")));
            assertTrue(dependencies.containsAll(
                    Set.of("workOrderRepository", "notificationPort")));
            assertTrue(dependencies.contains("workOrderGraph.AppConfig"));
        }
    }

    @Test
    void missingDependencyHasAStableCauseType() {
        assertRefreshFailureHasCause(MissingConfig.class, NoSuchBeanDefinitionException.class);
    }

    @Test
    void ambiguousDependencyHasAStableCauseType() {
        assertRefreshFailureHasCause(AmbiguousConfig.class, NoUniqueBeanDefinitionException.class);
    }

    @Test
    void constructorCycleHasAStableCauseType() {
        assertRefreshFailureHasCause(CycleConfig.class, BeanCurrentlyInCreationException.class);
    }

    @Test
    void fieldInjectionDependsOnContainerSideEffectsThatManualNewDoesNotRun() {
        var manual = new FieldInjectedService();
        assertFalse(manual.wired());
        assertThrows(NullPointerException.class, () -> manual.open("EQ-manual"));
        assertEquals(0, FieldInjectedService.class.getDeclaredConstructors()[0].getParameterCount());

        try (var context = new AnnotationConfigApplicationContext(FieldInjectionConfig.class)) {
            FieldInjectedService managed = context.getBean(FieldInjectedService.class);
            assertTrue(managed.wired());
            managed.open("EQ-managed");
            assertEquals(
                    List.of("EQ-managed"),
                    ((RecordingRepository) context.getBean("recordingRepository")).saved());
        }
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

    @Configuration(proxyBeanMethods = false)
    static class MissingConfig {
        @Bean
        NotificationPort notificationPort() {
            return message -> {
            };
        }

        @Bean
        WorkOrderService workOrderService(
                WorkOrderRepository repository, NotificationPort notifications) {
            return new WorkOrderService(repository, notifications);
        }
    }

    @Configuration(proxyBeanMethods = false)
    static class AmbiguousConfig {
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
                WorkOrderRepository repository, NotificationPort notifications) {
            return new WorkOrderService(repository, notifications);
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
    static class CycleConfig {
        @Bean
        CycleA cycleA(CycleB dependency) {
            return new CycleA(dependency);
        }

        @Bean
        CycleB cycleB(CycleA dependency) {
            return new CycleB(dependency);
        }
    }

    static final class RecordingRepository implements WorkOrderRepository {
        private final List<String> saved = new ArrayList<>();

        @Override
        public void save(String equipmentId) {
            saved.add(equipmentId);
        }

        List<String> saved() {
            return List.copyOf(saved);
        }
    }

    @Configuration(proxyBeanMethods = false)
    static class FieldInjectionConfig {
        @Bean
        WorkOrderRepository recordingRepository() {
            return new RecordingRepository();
        }

        @Bean
        FieldInjectedService fieldInjectedService() {
            return new FieldInjectedService();
        }
    }
}
