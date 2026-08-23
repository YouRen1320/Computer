package academy.domainexercise;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.lang.reflect.Modifier;
import java.util.Arrays;

import org.junit.jupiter.api.Test;

class StatusBypassTest {
    @Test
    void namedCommandsKeepTheLegalCreatedToAssignedPath() {
        var order = new StatusBypass.WorkOrder();
        assertEquals(StatusBypass.Status.CREATED, order.status());
        order.triage();
        assertEquals(StatusBypass.Status.TRIAGED, order.status());
        order.assign();
        assertEquals(StatusBypass.Status.ASSIGNED, order.status());
    }

    @Test
    void aggregateMustNotExposeAUniversalStatusSetter() {
        var publicMethods = Arrays.stream(StatusBypass.WorkOrder.class.getDeclaredMethods())
                .filter(method -> Modifier.isPublic(method.getModifiers()))
                .map(method -> method.getName())
                .toList();
        assertTrue(publicMethods.stream().noneMatch("setStatus"::equals),
                "EXPECTED_NO_PUBLIC_STATUS_SETTER: commands, not setters, protect transitions");
    }
}
