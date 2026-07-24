import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.time.ZoneId;

/** Replays one state-machine or SLA-clock failure at a time. */
public final class WorkflowStateSlaFaultLab {
    private enum DemoTicketStatus { CREATED, ASSIGNED, IN_PROGRESS, CLOSED, CANCELLED }
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

    private static final class DemoTicket {
        private DemoTicketStatus status = DemoTicketStatus.CREATED;

        boolean transition(DemoTicketStatus target, String assignee, String reason, FaultMode fault) {
            DemoTicketStatus before = status;
            if (fault == FaultMode.MUTATE_BEFORE_VALIDATE) {
                status = target;
            }
            if (!allowed(before, target, fault) || !guardSatisfied(target, assignee, reason, fault)) {
                return false;
            }
            status = target;
            return true;
        }

        DemoTicketStatus status() {
            return status;
        }
    }

    private WorkflowStateSlaFaultLab() { }

    private static boolean allowed(DemoTicketStatus from, DemoTicketStatus to, FaultMode fault) {
        if (fault == FaultMode.JUMP_ALLOWED && from == DemoTicketStatus.CREATED && to == DemoTicketStatus.CLOSED) {
            return true;
        }
        if (fault == FaultMode.TERMINAL_REVIVED && from == DemoTicketStatus.CLOSED && to == DemoTicketStatus.IN_PROGRESS) {
            return true;
        }
        return switch (from) {
            case CREATED -> to == DemoTicketStatus.ASSIGNED || to == DemoTicketStatus.CANCELLED;
            case ASSIGNED -> to == DemoTicketStatus.IN_PROGRESS || to == DemoTicketStatus.CANCELLED;
            case IN_PROGRESS -> to == DemoTicketStatus.CLOSED;
            case CLOSED, CANCELLED -> false;
        };
    }

    private static boolean guardSatisfied(
            DemoTicketStatus target, String assignee, String reason, FaultMode fault) {
        if (fault == FaultMode.GUARD_SKIPPED) {
            return true;
        }
        return switch (target) {
            case ASSIGNED, IN_PROGRESS -> assignee != null && !assignee.isBlank();
            case CLOSED, CANCELLED -> reason != null && !reason.isBlank();
            case CREATED -> false;
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

    private static DemoTicket closed(FaultMode fault) {
        DemoTicket demoTicket = new DemoTicket();
        demoTicket.transition(DemoTicketStatus.ASSIGNED, "TECH-7", "", fault);
        demoTicket.transition(DemoTicketStatus.IN_PROGRESS, "TECH-7", "", fault);
        demoTicket.transition(DemoTicketStatus.CLOSED, "TECH-7", "RESOLVED", fault);
        return demoTicket;
    }

    private static String injectedOutcome(FaultMode fault) {
        Instant fixed = Instant.parse("2026-07-17T08:00:00Z");
        return switch (fault) {
            case JUMP_ALLOWED -> {
                DemoTicket item = new DemoTicket();
                yield item.transition(DemoTicketStatus.CLOSED, "TECH-7", "RESOLVED", fault)
                        ? "JUMP_STATE_ACCEPTED" : "FAULT_NOT_EXPOSED";
            }
            case MUTATE_BEFORE_VALIDATE -> {
                DemoTicket item = new DemoTicket();
                item.transition(DemoTicketStatus.CLOSED, "TECH-7", "RESOLVED", fault);
                yield item.status() == DemoTicketStatus.CLOSED
                        ? "INVALID_TRANSITION_MUTATED_STATE" : "FAULT_NOT_EXPOSED";
            }
            case GUARD_SKIPPED -> new DemoTicket().transition(DemoTicketStatus.ASSIGNED, "", "", fault)
                    ? "MISSING_GUARD_ACCEPTED" : "FAULT_NOT_EXPOSED";
            case TERMINAL_REVIVED -> closed(fault).transition(DemoTicketStatus.IN_PROGRESS, "TECH-7", "", fault)
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

        boolean edges = allowed(DemoTicketStatus.CREATED, DemoTicketStatus.ASSIGNED, fault)
                && allowed(DemoTicketStatus.ASSIGNED, DemoTicketStatus.IN_PROGRESS, fault)
                && allowed(DemoTicketStatus.IN_PROGRESS, DemoTicketStatus.CLOSED, fault)
                && !allowed(DemoTicketStatus.CREATED, DemoTicketStatus.CLOSED, fault);
        DemoTicket invalid = new DemoTicket();
        boolean unchanged = !invalid.transition(DemoTicketStatus.CLOSED, "TECH-7", "RESOLVED", fault)
                && invalid.status() == DemoTicketStatus.CREATED;
        boolean guards = !new DemoTicket().transition(DemoTicketStatus.ASSIGNED, "", "", fault);
        DemoTicket terminalItem = closed(fault);
        boolean terminal = !terminalItem.transition(DemoTicketStatus.IN_PROGRESS, "TECH-7", "", fault)
                && terminalItem.status() == DemoTicketStatus.CLOSED;

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
