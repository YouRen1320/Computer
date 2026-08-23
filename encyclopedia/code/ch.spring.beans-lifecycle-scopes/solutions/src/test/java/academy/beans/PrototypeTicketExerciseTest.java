package academy.beans;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotSame;
import static org.junit.jupiter.api.Assertions.assertSame;

import academy.beans.PrototypeTicketExercise.PrototypeTicket;
import academy.beans.PrototypeTicketExercise.TicketIssuer;
import java.lang.reflect.Field;
import java.util.Arrays;
import java.util.List;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.ObjectProvider;
import org.springframework.context.annotation.AnnotationConfigApplicationContext;

class PrototypeTicketExerciseTest {
    @Test
    void directContainerLookupsRespectPrototypeScope() {
        try (var context = newContext()) {
            PrototypeTicket first = context.getBean(PrototypeTicket.class);
            PrototypeTicket second = context.getBean(PrototypeTicket.class);

            assertNotSame(first, second);
        }
    }

    @Test
    void issuerRemainsOneSingletonInsideItsContainer() {
        try (var context = newContext()) {
            assertSame(
                    context.getBean(TicketIssuer.class),
                    context.getBean(TicketIssuer.class));
        }
    }

    @Test
    void singletonLooksUpOneFreshPrototypeForEveryIssueCall() {
        try (var context = newContext()) {
            TicketIssuer issuer = context.getBean(TicketIssuer.class);

            assertNotSame(
                    issuer.issue(),
                    issuer.issue(),
                    "EXPECTED_FRESH_PROTOTYPE");

            List<Class<?>> dependencyTypes = Arrays.stream(TicketIssuer.class.getDeclaredFields())
                    .filter(field -> !field.isSynthetic())
                    .map(Field::getType)
                    .toList();
            assertEquals(
                    List.of(ObjectProvider.class),
                    dependencyTypes,
                    "EXPECTED_FRESH_PROTOTYPE");
        }
    }

    private static AnnotationConfigApplicationContext newContext() {
        return new AnnotationConfigApplicationContext(PrototypeTicketExercise.class);
    }
}
