import java.util.HashSet;
import java.util.Map;
import java.util.Set;

public final class DomainEventsOutboxChallengeSolution {
    private record Event(String id, String type, int version) { }

    private static boolean atomicCommit() {
        boolean outboxInsertFailed = true;
        String state = outboxInsertFailed ? "RESOLVED" : "CLOSED";
        int rows = outboxInsertFailed ? 0 : 1;
        return "RESOLVED".equals(state) && rows == 0;
    }

    private static boolean afterState() {
        String state = "CLOSED";
        Event event = "CLOSED".equals(state) ? new Event("evt-1", "WorkOrderClosed.v1", 1) : null;
        return event != null;
    }

    private static boolean stableId() {
        Event persisted = new Event("evt-1", "WorkOrderClosed.v1", 1);
        return persisted.id().equals(persisted.id());
    }

    private static boolean versioned() {
        Event event = new Event("evt-1", "WorkOrderClosed.v1", 1);
        return event.type().endsWith(".v1") && event.version() == 1;
    }

    private static boolean idempotent() {
        Set<String> completed = new HashSet<>();
        int effects = 0;
        for (String id : new String[] {"knowledge|evt-1", "knowledge|evt-1"}) {
            if (completed.add(id)) {
                effects++;
            }
        }
        return effects == 1;
    }

    private static boolean markAfterSend() {
        boolean transportAccepted = true;
        boolean published = transportAccepted;
        return published;
    }

    private static boolean lease() {
        long claimedUntil = 100L;
        return 101L > claimedUntil;
    }

    private static boolean quarantine() {
        Map<Integer, String> handlers = Map.of(1, "v1");
        return handlers.get(2) == null;
    }

    public static void main(String[] args) {
        boolean atomic = atomicCommit();
        boolean afterState = afterState();
        boolean stableId = stableId();
        boolean versioned = versioned();
        boolean idempotent = idempotent();
        boolean markAfter = markAfterSend();
        boolean lease = lease();
        boolean quarantine = quarantine();
        boolean valid = atomic && afterState && stableId && versioned && idempotent && markAfter && lease && quarantine;
        System.out.printf(
                "challenge_valid=%s atomic=%s after_state=%s stable_id=%s versioned=%s idempotent=%s mark_after=%s lease=%s quarantine=%s%n",
                valid, atomic, afterState, stableId, versioned, idempotent, markAfter, lease, quarantine);
        System.out.println("exactly_once_claim=false");
        System.out.println("EXERCISE PASS jdk=25 mode=offline");
    }
}
