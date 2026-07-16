package academy.ioc;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

import academy.ioc.WorkOrderExercise.NotificationPort;
import academy.ioc.WorkOrderExercise.WorkOrderRepository;
import academy.ioc.WorkOrderExercise.WorkOrderService;
import java.lang.reflect.Modifier;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;
import java.util.Set;
import org.junit.jupiter.api.Test;

class WorkOrderExerciseTest {
    @Test
    void requiredDependenciesAreExplicitAndDriveTheBehavior() {
        List<String> saved = new ArrayList<>();
        List<String> sent = new ArrayList<>();

        WorkOrderService service;
        try {
            service = WorkOrderService.class
                    .getDeclaredConstructor(WorkOrderRepository.class, NotificationPort.class)
                    .newInstance((WorkOrderRepository) saved::add, (NotificationPort) sent::add);
        } catch (ReflectiveOperationException failure) {
            throw new AssertionError("EXPECTED_EXPLICIT_CONSTRUCTOR_GRAPH", failure);
        }

        assertEquals("opened:EQ-replace", service.open("EQ-replace"));
        assertEquals(List.of("EQ-replace"), saved, "EXPECTED_EXPLICIT_CONSTRUCTOR_GRAPH");
        assertEquals(List.of("opened:EQ-replace"), sent, "EXPECTED_EXPLICIT_CONSTRUCTOR_GRAPH");

        var dependencyFields = Arrays.stream(WorkOrderService.class.getDeclaredFields())
                .filter(field -> !Modifier.isStatic(field.getModifiers()))
                .toList();
        assertEquals(
                Set.of(WorkOrderRepository.class, NotificationPort.class),
                dependencyFields.stream().map(field -> field.getType()).collect(
                        java.util.stream.Collectors.toSet()),
                "EXPECTED_EXPLICIT_CONSTRUCTOR_GRAPH");
        assertTrue(
                dependencyFields.stream().allMatch(field -> Modifier.isFinal(field.getModifiers())),
                "EXPECTED_EXPLICIT_CONSTRUCTOR_GRAPH");
    }

    @Test
    void blankIdentifierFailsBeforeAnyCollaboration() {
        List<String> calls = new ArrayList<>();
        WorkOrderService service = newService(calls::add, calls::add);

        assertThrows(IllegalArgumentException.class, () -> service.open(" "));
        assertEquals(List.of(), calls);
    }

    @Test
    void eventFormatRemainsStableDuringTheRefactor() {
        WorkOrderService service = newService(equipmentId -> {
        }, message -> {
        });

        assertEquals("opened:EQ-format", service.open("EQ-format"));
    }

    private static WorkOrderService newService(
            WorkOrderRepository repository, NotificationPort notifications) {
        try {
            try {
                return WorkOrderService.class
                        .getDeclaredConstructor(WorkOrderRepository.class, NotificationPort.class)
                        .newInstance(repository, notifications);
            } catch (NoSuchMethodException ignored) {
                return WorkOrderService.class.getDeclaredConstructor().newInstance();
            }
        } catch (ReflectiveOperationException failure) {
            throw new AssertionError(failure);
        }
    }
}
