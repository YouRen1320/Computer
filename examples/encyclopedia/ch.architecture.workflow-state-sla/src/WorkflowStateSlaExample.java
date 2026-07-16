import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.time.ZoneId;
import java.util.ArrayList;
import java.util.List;

/** Demonstrates a deliberately reduced state machine and reproducible SLA clock. */
public final class WorkflowStateSlaExample {
    private enum Status { NEW, ASSIGNED, IN_PROGRESS, CLOSED, CANCELLED }
    private record Transition(Status from, Status to, Instant occurredAt) { }

    private static final class WorkOrder {
        private Status status = Status.NEW;
        private final List<Transition> history = new ArrayList<>();

        boolean transition(Status target, String assignee, String reason, Clock clock) {
            Status before = status;
            if (!allowed(before, target) || !guardSatisfied(target, assignee, reason)) {
                return false;
            }
            status = target;
            history.add(new Transition(before, target, clock.instant()));
            return true;
        }

        Status status() {
            return status;
        }

        List<Transition> history() {
            return List.copyOf(history);
        }
    }

    private WorkflowStateSlaExample() { }

    private static boolean allowed(Status from, Status to) {
        return switch (from) {
            case NEW -> to == Status.ASSIGNED || to == Status.CANCELLED;
            case ASSIGNED -> to == Status.IN_PROGRESS || to == Status.CANCELLED;
            case IN_PROGRESS -> to == Status.CLOSED;
            case CLOSED, CANCELLED -> false;
        };
    }

    private static boolean guardSatisfied(Status target, String assignee, String reason) {
        return switch (target) {
            case ASSIGNED, IN_PROGRESS -> assignee != null && !assignee.isBlank();
            case CLOSED, CANCELLED -> reason != null && !reason.isBlank();
            case NEW -> false;
        };
    }

    private static Instant resumedDeadline(Instant deadline, Instant pauseStarted, Instant resumedAt) {
        return deadline.plus(Duration.between(pauseStarted, resumedAt));
    }

    public static void main(String[] args) {
        Instant start = Instant.parse("2026-07-17T08:00:00Z");
        Clock clock = Clock.fixed(start, ZoneId.of("UTC"));
        WorkOrder workOrder = new WorkOrder();
        workOrder.transition(Status.ASSIGNED, "TECH-7", "", clock);
        workOrder.transition(Status.IN_PROGRESS, "TECH-7", "", clock);
        workOrder.transition(Status.CLOSED, "TECH-7", "RESOLVED", clock);

        WorkOrder jump = new WorkOrder();
        boolean jumpRejected = !jump.transition(Status.CLOSED, "TECH-7", "RESOLVED", clock)
                && jump.status() == Status.NEW;
        WorkOrder missingGuard = new WorkOrder();
        boolean guardRejected = !missingGuard.transition(Status.ASSIGNED, "", "", clock)
                && missingGuard.status() == Status.NEW;
        boolean terminal = !workOrder.transition(Status.IN_PROGRESS, "TECH-7", "", clock)
                && workOrder.status() == Status.CLOSED;

        Instant baseDeadline = start.plus(Duration.ofHours(4));
        Instant extended = resumedDeadline(baseDeadline, start.plus(Duration.ofHours(1)),
                start.plus(Duration.ofHours(3)));
        Clock atDeadline = Clock.fixed(extended, ZoneId.of("UTC"));
        boolean timedOut = !atDeadline.instant().isBefore(extended);
        boolean sameFact = extended.atZone(ZoneId.of("Asia/Shanghai")).toInstant().equals(extended)
                && extended.atZone(ZoneId.of("America/New_York")).toInstant().equals(extended);

        System.out.println("allowed_path=NEW>ASSIGNED>IN_PROGRESS>CLOSED");
        System.out.println("jump_rejected=" + jumpRejected);
        System.out.println("guard_rejected=" + guardRejected);
        System.out.println("terminal_irreversible=" + terminal);
        System.out.println("base_deadline=" + baseDeadline);
        System.out.println("pause_extends_deadline=" + extended);
        System.out.println("fixed_clock_timeout=" + timedOut);
        System.out.println("timezone_fact_same=" + sameFact);
        System.out.println("history_events=" + workOrder.history().size());
    }
}
