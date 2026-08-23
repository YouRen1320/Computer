package academy.beans;

import java.util.concurrent.atomic.AtomicInteger;
import org.springframework.beans.factory.ObjectProvider;
import org.springframework.beans.factory.config.ConfigurableBeanFactory;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.annotation.Scope;

/** Resolves a prototype at the operation boundary while keeping the issuer singleton-scoped. */
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
    TicketIssuer ticketIssuer(ObjectProvider<PrototypeTicket> tickets) {
        return new TicketIssuer(tickets);
    }

    public record PrototypeTicket(int id) {
    }

    public static final class TicketIssuer {
        private final ObjectProvider<PrototypeTicket> tickets;

        TicketIssuer(ObjectProvider<PrototypeTicket> tickets) {
            this.tickets = tickets;
        }

        public PrototypeTicket issue() {
            return tickets.getObject();
        }
    }
}
