import java.time.Clock;
import java.time.Duration;
import java.time.Instant;

/** Red starter for a reduced workflow and deterministic SLA clock. */
public final class WorkflowStateSlaChallenge {
    enum Status { NEW, ASSIGNED, IN_PROGRESS, CLOSED, CANCELLED }

    private WorkflowStateSlaChallenge() { }

    public static void main(String[] args) {
        require(allowed(Status.NEW, Status.ASSIGNED), "VALID_ASSIGN_REJECTED");
        require(!allowed(Status.NEW, Status.CLOSED), "JUMP_STATE_ACCEPTED");
        require(guardSatisfied(Status.ASSIGNED, "TECH-7", ""), "VALID_GUARD_REJECTED");
        require(!guardSatisfied(Status.ASSIGNED, "", ""), "MISSING_GUARD_ACCEPTED");
        require(invalidPreservesState(Status.NEW, Status.NEW), "INVALID_TRANSITION_MUTATED_STATE");
        require(!invalidPreservesState(Status.NEW, Status.CLOSED), "MUTATION_NOT_DETECTED");
        require(terminalImmutable(Status.CLOSED, Status.IN_PROGRESS), "TERMINAL_STATE_REVIVED");
        require(terminalImmutable(Status.CANCELLED, Status.ASSIGNED), "CANCELLED_STATE_REVIVED");

        Instant start = Instant.parse("2026-07-17T08:00:00Z");
        Instant base = deadline(start, Duration.ofHours(4));
        require(base.equals(Instant.parse("2026-07-17T12:00:00Z")), "DEADLINE_DRIFTED");
        Instant resumed = resumeDeadline(base, start.plus(Duration.ofHours(1)),
                start.plus(Duration.ofHours(3)));
        require(resumed.equals(Instant.parse("2026-07-17T14:00:00Z")),
                "PAUSE_WINDOW_COUNTED_WRONG");
        require(timedOut(resumed, Clock.fixed(resumed, java.time.ZoneOffset.UTC)),
                "DEADLINE_BOUNDARY_NOT_TIMED_OUT");
        require(!timedOut(resumed, Clock.fixed(resumed.minusNanos(1), java.time.ZoneOffset.UTC)),
                "EARLY_TIMEOUT_ACCEPTED");

        System.out.println("challenge_valid=true transitions=true guards=true unchanged=true terminal=true deadline=true pause=true timeout=true");
        System.out.println("EXERCISE PASS jdk=25 mode=offline");
    }

    static boolean allowed(Status from, Status to) {
        // TODO allow only the documented reduced-state transitions.
        return true;
    }

    static boolean guardSatisfied(Status target, String assignee, String reason) {
        // TODO require assignee for assignment/start and reason for close/cancel.
        return true;
    }

    static boolean invalidPreservesState(Status before, Status after) {
        // TODO prove a rejected transition leaves the state unchanged.
        return true;
    }

    static boolean terminalImmutable(Status terminal, Status attemptedTarget) {
        // TODO reject every outgoing transition from the reduced model's terminal states.
        return true;
    }

    static Instant deadline(Instant start, Duration budget) {
        // TODO calculate a continuous deadline on the instant time-line.
        return start;
    }

    static Instant resumeDeadline(Instant currentDeadline, Instant pauseStarted, Instant resumedAt) {
        // TODO extend the deadline by exactly one paused interval.
        return currentDeadline;
    }

    static boolean timedOut(Instant deadline, Clock clock) {
        // TODO use the injected clock and treat now >= deadline as timed out.
        return false;
    }

    private static void require(boolean condition, String marker) {
        if (!condition) {
            throw new IllegalStateException(marker);
        }
    }
}
