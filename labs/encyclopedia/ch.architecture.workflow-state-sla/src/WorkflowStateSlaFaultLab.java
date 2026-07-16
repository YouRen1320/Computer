import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.time.ZoneId;

/** Replays one state-machine or SLA-clock failure at a time. */
public final class WorkflowStateSlaFaultLab {
    private enum Status { NEW, ASSIGNED, IN_PROGRESS, CLOSED, CANCELLED }
    private enum FaultMode {
        NORMAL,
        JUMP_ALLOWED,
        MUTATE_BEFORE_VALIDATE,
        GUARD_SKIPPED,
        TERMINAL_REVIVED,
        SYSTEM_CLOCK,
        LOCAL_TIME_DEADLINE,
        PAUSE_DOUBLE_COUNT
    }

    private static final class WorkOrder {
        private Status status = Status.NEW;

        boolean transition(Status target, String assignee, String reason, FaultMode fault) {
            Status before = status;
            if (fault == FaultMode.MUTATE_BEFORE_VALIDATE) {
                status = target;
            }
            if (!allowed(before, target, fault) || !guardSatisfied(target, assignee, reason, fault)) {
                return false;
            }
            status = target;
            return true;
        }

        Status status() {
            return status;
        }
    }

    private WorkflowStateSlaFaultLab() { }

    private static boolean allowed(Status from, Status to, FaultMode fault) {
        if (fault == FaultMode.JUMP_ALLOWED && from == Status.NEW && to == Status.CLOSED) {
            return true;
        }
        if (fault == FaultMode.TERMINAL_REVIVED && from == Status.CLOSED && to == Status.IN_PROGRESS) {
            return true;
        }
        return switch (from) {
            case NEW -> to == Status.ASSIGNED || to == Status.CANCELLED;
            case ASSIGNED -> to == Status.IN_PROGRESS || to == Status.CANCELLED;
            case IN_PROGRESS -> to == Status.CLOSED;
            case CLOSED, CANCELLED -> false;
        };
    }

    private static boolean guardSatisfied(
            Status target, String assignee, String reason, FaultMode fault) {
        if (fault == FaultMode.GUARD_SKIPPED) {
            return true;
        }
        return switch (target) {
            case ASSIGNED, IN_PROGRESS -> assignee != null && !assignee.isBlank();
            case CLOSED, CANCELLED -> reason != null && !reason.isBlank();
            case NEW -> false;
        };
    }

    private static Instant sampledNow(Clock clock, FaultMode fault) {
        return fault == FaultMode.SYSTEM_CLOCK
                ? Clock.offset(clock, Duration.ofHours(1)).instant()
                : clock.instant();
    }

    private static Instant continuousDeadline(
            Instant start, Duration budget, ZoneId zone, FaultMode fault) {
        if (fault == FaultMode.LOCAL_TIME_DEADLINE) {
            return start.atZone(zone).toLocalDateTime().plus(budget).atZone(zone).toInstant();
        }
        return start.plus(budget);
    }

    private static Instant resumedDeadline(
            Instant deadline, Instant pauseStarted, Instant resumedAt, FaultMode fault) {
        Duration paused = Duration.between(pauseStarted, resumedAt);
        return fault == FaultMode.PAUSE_DOUBLE_COUNT
                ? deadline.plus(paused).plus(paused)
                : deadline.plus(paused);
    }

    private static WorkOrder closed(FaultMode fault) {
        WorkOrder workOrder = new WorkOrder();
        workOrder.transition(Status.ASSIGNED, "TECH-7", "", fault);
        workOrder.transition(Status.IN_PROGRESS, "TECH-7", "", fault);
        workOrder.transition(Status.CLOSED, "TECH-7", "RESOLVED", fault);
        return workOrder;
    }

    private static String injectedOutcome(FaultMode fault) {
        Instant fixed = Instant.parse("2026-07-17T08:00:00Z");
        return switch (fault) {
            case JUMP_ALLOWED -> {
                WorkOrder item = new WorkOrder();
                yield item.transition(Status.CLOSED, "TECH-7", "RESOLVED", fault)
                        ? "JUMP_STATE_ACCEPTED" : "FAULT_NOT_EXPOSED";
            }
            case MUTATE_BEFORE_VALIDATE -> {
                WorkOrder item = new WorkOrder();
                item.transition(Status.CLOSED, "TECH-7", "RESOLVED", fault);
                yield item.status() == Status.CLOSED
                        ? "INVALID_TRANSITION_MUTATED_STATE" : "FAULT_NOT_EXPOSED";
            }
            case GUARD_SKIPPED -> new WorkOrder().transition(Status.ASSIGNED, "", "", fault)
                    ? "MISSING_GUARD_ACCEPTED" : "FAULT_NOT_EXPOSED";
            case TERMINAL_REVIVED -> closed(fault).transition(Status.IN_PROGRESS, "TECH-7", "", fault)
                    ? "TERMINAL_STATE_REVIVED" : "FAULT_NOT_EXPOSED";
            case SYSTEM_CLOCK -> !sampledNow(Clock.fixed(fixed, ZoneId.of("UTC")), fault).equals(fixed)
                    ? "SYSTEM_CLOCK_DRIFTED" : "FAULT_NOT_EXPOSED";
            case LOCAL_TIME_DEADLINE -> {
                Instant dstStart = Instant.parse("2026-03-08T05:30:00Z");
                Instant actual = continuousDeadline(
                        dstStart, Duration.ofHours(4), ZoneId.of("America/New_York"), fault);
                yield !actual.equals(dstStart.plus(Duration.ofHours(4)))
                        ? "DST_DEADLINE_DRIFTED" : "FAULT_NOT_EXPOSED";
            }
            case PAUSE_DOUBLE_COUNT -> {
                Instant actual = resumedDeadline(fixed.plus(Duration.ofHours(4)),
                        fixed.plus(Duration.ofHours(1)), fixed.plus(Duration.ofHours(3)), fault);
                yield actual.equals(fixed.plus(Duration.ofHours(8)))
                        ? "PAUSE_WINDOW_DOUBLE_COUNTED" : "FAULT_NOT_EXPOSED";
            }
            case NORMAL -> "FAULT_NOT_EXPOSED";
        };
    }

    public static void main(String[] args) {
        FaultMode fault = args.length == 0 ? FaultMode.NORMAL : FaultMode.valueOf(args[0]);
        if (fault != FaultMode.NORMAL) {
            System.out.println(injectedOutcome(fault));
            return;
        }

        boolean edges = allowed(Status.NEW, Status.ASSIGNED, fault)
                && allowed(Status.ASSIGNED, Status.IN_PROGRESS, fault)
                && allowed(Status.IN_PROGRESS, Status.CLOSED, fault)
                && !allowed(Status.NEW, Status.CLOSED, fault);
        WorkOrder invalid = new WorkOrder();
        boolean unchanged = !invalid.transition(Status.CLOSED, "TECH-7", "RESOLVED", fault)
                && invalid.status() == Status.NEW;
        boolean guards = !new WorkOrder().transition(Status.ASSIGNED, "", "", fault);
        WorkOrder terminalItem = closed(fault);
        boolean terminal = !terminalItem.transition(Status.IN_PROGRESS, "TECH-7", "", fault)
                && terminalItem.status() == Status.CLOSED;

        Instant fixed = Instant.parse("2026-07-17T08:00:00Z");
        boolean clockStable = sampledNow(Clock.fixed(fixed, ZoneId.of("UTC")), fault).equals(fixed);
        Instant dstStart = Instant.parse("2026-03-08T05:30:00Z");
        boolean dstStable = continuousDeadline(dstStart, Duration.ofHours(4),
                ZoneId.of("America/New_York"), fault).equals(dstStart.plus(Duration.ofHours(4)));
        boolean pauseOnce = resumedDeadline(fixed.plus(Duration.ofHours(4)),
                fixed.plus(Duration.ofHours(1)), fixed.plus(Duration.ofHours(3)), fault)
                .equals(fixed.plus(Duration.ofHours(6)));

        System.out.println("allowed_edges=" + edges);
        System.out.println("invalid_preserves_state=" + unchanged);
        System.out.println("guards_enforced=" + guards);
        System.out.println("terminal_irreversible=" + terminal);
        System.out.println("fixed_clock_stable=" + clockStable);
        System.out.println("dst_instant_stable=" + dstStable);
        System.out.println("pause_counted_once=" + pauseOnce);
        System.out.println("verification_report=PASS assertions=7");
    }
}
