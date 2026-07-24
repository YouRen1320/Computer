import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.time.ZoneId;
import java.util.ArrayList;
import java.util.List;

/** Demonstrates a deliberately reduced state machine and reproducible SLA clock. */
public final class WorkflowStateSlaExample {
    private enum DemoTicketStatus { CREATED, ASSIGNED, IN_PROGRESS, CLOSED, CANCELLED }
    private record Transition(DemoTicketStatus from, DemoTicketStatus to, Instant occurredAt) { }

    private static final class DemoTicket {
        private DemoTicketStatus status = DemoTicketStatus.CREATED;
        private final List<Transition> history = new ArrayList<>();

        boolean transition(DemoTicketStatus target, String assignee, String reason, Clock clock) {
            DemoTicketStatus before = status;
            if (!allowed(before, target) || !guardSatisfied(target, assignee, reason)) {
                return false;
            }
            status = target;
            history.add(new Transition(before, target, clock.instant()));
            return true;
        }

        DemoTicketStatus status() {
            return status;
        }

        List<Transition> history() {
            return List.copyOf(history);
        }
    }

    private WorkflowStateSlaExample() { }

    private static boolean allowed(DemoTicketStatus from, DemoTicketStatus to) {
        return switch (from) {
            case CREATED -> to == DemoTicketStatus.ASSIGNED || to == DemoTicketStatus.CANCELLED;
            case ASSIGNED -> to == DemoTicketStatus.IN_PROGRESS || to == DemoTicketStatus.CANCELLED;
            case IN_PROGRESS -> to == DemoTicketStatus.CLOSED;
            case CLOSED, CANCELLED -> false;
        };
    }

    private static boolean guardSatisfied(DemoTicketStatus target, String assignee, String reason) {
        return switch (target) {
            case ASSIGNED, IN_PROGRESS -> assignee != null && !assignee.isBlank();
            case CLOSED, CANCELLED -> reason != null && !reason.isBlank();
            case CREATED -> false;
        };
    }

    private static Instant resumedDeadline(Instant deadline, Instant pauseStarted, Instant resumedAt) {
        return deadline.plus(Duration.between(pauseStarted, resumedAt));
    }

    public static void main(String[] args) {
        Instant start = Instant.parse("2026-07-17T08:00:00Z");
        Clock clock = Clock.fixed(start, ZoneId.of("UTC"));
        DemoTicket demoTicket = new DemoTicket();
        demoTicket.transition(DemoTicketStatus.ASSIGNED, "TECH-7", "", clock);
        demoTicket.transition(DemoTicketStatus.IN_PROGRESS, "TECH-7", "", clock);
        demoTicket.transition(DemoTicketStatus.CLOSED, "TECH-7", "RESOLVED", clock);

        DemoTicket jump = new DemoTicket();
        boolean jumpRejected = !jump.transition(DemoTicketStatus.CLOSED, "TECH-7", "RESOLVED", clock)
                && jump.status() == DemoTicketStatus.CREATED;
        DemoTicket missingGuard = new DemoTicket();
        boolean guardRejected = !missingGuard.transition(DemoTicketStatus.ASSIGNED, "", "", clock)
                && missingGuard.status() == DemoTicketStatus.CREATED;
        boolean terminal = !demoTicket.transition(DemoTicketStatus.IN_PROGRESS, "TECH-7", "", clock)
                && demoTicket.status() == DemoTicketStatus.CLOSED;

        Instant baseDeadline = start.plus(Duration.ofHours(4));
        Instant extended = resumedDeadline(baseDeadline, start.plus(Duration.ofHours(1)),
                start.plus(Duration.ofHours(3)));
        Clock atDeadline = Clock.fixed(extended, ZoneId.of("UTC"));
        boolean timedOut = !atDeadline.instant().isBefore(extended);
        boolean sameFact = extended.atZone(ZoneId.of("Asia/Shanghai")).toInstant().equals(extended)
                && extended.atZone(ZoneId.of("America/New_York")).toInstant().equals(extended);

        System.out.println("allowed_path=CREATED>ASSIGNED>IN_PROGRESS>CLOSED");
        System.out.println("jump_rejected=" + jumpRejected);
        System.out.println("guard_rejected=" + guardRejected);
        System.out.println("terminal_irreversible=" + terminal);
        System.out.println("base_deadline=" + baseDeadline);
        System.out.println("pause_extends_deadline=" + extended);
        System.out.println("fixed_clock_timeout=" + timedOut);
        System.out.println("timezone_fact_same=" + sameFact);
        System.out.println("history_events=" + demoTicket.history().size());
    }
}
