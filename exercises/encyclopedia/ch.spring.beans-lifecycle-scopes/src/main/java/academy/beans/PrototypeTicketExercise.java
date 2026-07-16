package academy.beans;

import java.util.concurrent.atomic.AtomicInteger;
import org.springframework.beans.factory.config.ConfigurableBeanFactory;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.annotation.Scope;

/** Demonstrates the scope boundary when a singleton captures one prototype dependency. */
@Configuration(proxyBeanMethods = false)
public class PrototypeTicketExercise {
    @Bean
    AtomicInteger ticketSequence() {
        return new AtomicInteger();
    }

    @Bean
    @Scope(ConfigurableBeanFactory.SCOPE_PROTOTYPE)
    PrototypeTicket prototypeTicket(AtomicInteger ticketSequence) {
        return new PrototypeTicket(ticketSequence.incrementAndGet());
    }

    @Bean
    TicketIssuer ticketIssuer(PrototypeTicket capturedTicket) {
        return new TicketIssuer(capturedTicket);
    }

    public record PrototypeTicket(int id) {
    }

    public static final class TicketIssuer {
        private final PrototypeTicket capturedTicket;

        TicketIssuer(PrototypeTicket capturedTicket) {
            this.capturedTicket = capturedTicket;
        }

        public PrototypeTicket issue() {
            // TODO Obtain a prototype at call time instead of retaining the startup instance.
            return capturedTicket;
        }
    }
}
