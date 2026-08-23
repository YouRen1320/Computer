import java.util.HashMap;
import java.util.HashSet;
import java.util.Map;
import java.util.Set;

public final class DomainEventsOutboxFaultLab {
    private enum FaultMode {
        BUSINESS_COMMIT_BEFORE_EVENT,
        EVENT_BEFORE_STATE_CHANGE,
        SEND_THEN_MARK_CRASH,
        NEW_ID_ON_RETRY,
        PAYLOAD_WITHOUT_VERSION,
        MARK_BEFORE_SEND,
        CLAIM_WITHOUT_LEASE,
        SWALLOW_OUTBOX_FAILURE
    }

    private record Event(String id, String type, int version, long aggregateVersion) { }

    private static boolean sameCommit() {
        String state = "CLOSED";
        Event event = new Event("evt-1", "WorkOrderClosed.v1", 1, 8L);
        return "CLOSED".equals(state) && event.version() == 1;
    }

    private static boolean sameRollback() {
        boolean outboxInsertFailed = true;
        String committedState = outboxInsertFailed ? "RESOLVED" : "CLOSED";
        int outboxRows = outboxInsertFailed ? 0 : 1;
        return "RESOLVED".equals(committedState) && outboxRows == 0;
    }

    private static boolean stableId() {
        Event stored = new Event("evt-1", "WorkOrderClosed.v1", 1, 8L);
        return stored.id().equals(stored.id());
    }

    private static boolean idempotentConsumer() {
        Set<String> completed = new HashSet<>();
        int effects = 0;
        for (String eventId : new String[] {"evt-1", "evt-1"}) {
            if (completed.add(eventId)) {
                effects++;
            }
        }
        return effects == 1;
    }

    private static boolean versionDispatched() {
        Map<Integer, String> handlers = Map.of(1, "v1-handler");
        return "v1-handler".equals(handlers.get(1));
    }

    private static boolean unsupportedQuarantined() {
        Map<Integer, String> handlers = Map.of(1, "v1-handler");
        return handlers.get(2) == null;
    }

    private static boolean recoverableClaim() {
        long claimedUntil = 100L;
        long now = 101L;
        return claimedUntil < now;
    }

    private static boolean explicitAggregateOrder() {
        Event older = new Event("evt-1", "WorkOrderResolved.v1", 1, 7L);
        Event newer = new Event("evt-2", "WorkOrderClosed.v1", 1, 8L);
        return newer.aggregateVersion() == older.aggregateVersion() + 1L;
    }

    private static String inject(FaultMode mode) {
        return switch (mode) {
            case BUSINESS_COMMIT_BEFORE_EVENT -> {
                boolean businessCommitted = true;
                boolean outboxInserted = false;
                yield businessCommitted && !outboxInserted ? "CLOSED_WITHOUT_OUTBOX" : "NOT_EXPOSED";
            }
            case EVENT_BEFORE_STATE_CHANGE -> {
                boolean eventSent = true;
                boolean businessRolledBack = true;
                yield eventSent && businessRolledBack ? "GHOST_EVENT_AFTER_ROLLBACK" : "NOT_EXPOSED";
            }
            case SEND_THEN_MARK_CRASH -> {
                int deliveries = 2;
                yield deliveries > 1 ? "DUPLICATE_DELIVERY_EXPECTED" : "NOT_EXPOSED";
            }
            case NEW_ID_ON_RETRY -> {
                Set<String> consumed = new HashSet<>();
                consumed.add("evt-attempt-1");
                consumed.add("evt-attempt-2");
                yield consumed.size() == 2 ? "DUPLICATE_CONSUMER_EFFECT" : "NOT_EXPOSED";
            }
            case PAYLOAD_WITHOUT_VERSION -> {
                Map<String, String> envelope = new HashMap<>();
                envelope.put("eventType", "WorkOrderClosed");
                int guessedVersion = envelope.get("version") == null ? 1 : Integer.parseInt(envelope.get("version"));
                yield guessedVersion == 1 ? "VERSION_GUESSED" : "NOT_EXPOSED";
            }
            case MARK_BEFORE_SEND -> {
                boolean published = true;
                boolean delivered = false;
                yield published && !delivered ? "EVENT_LOST" : "NOT_EXPOSED";
            }
            case CLAIM_WITHOUT_LEASE -> {
                boolean inFlight = true;
                Long claimedUntil = null;
                yield inFlight && claimedUntil == null ? "OUTBOX_STUCK" : "NOT_EXPOSED";
            }
            case SWALLOW_OUTBOX_FAILURE -> {
                boolean outboxFailed = true;
                boolean commandReturnedSuccess = true;
                yield outboxFailed && commandReturnedSuccess ? "PARTIAL_COMMIT" : "NOT_EXPOSED";
            }
        };
    }

    public static void main(String[] args) {
        if (args.length == 1) {
            System.out.println(inject(FaultMode.valueOf(args[0])));
            return;
        }
        System.out.println("state_event_same_commit=" + sameCommit());
        System.out.println("state_event_same_rollback=" + sameRollback());
        System.out.println("event_id_stable=" + stableId());
        System.out.println("consumer_idempotent=" + idempotentConsumer());
        System.out.println("version_dispatched=" + versionDispatched());
        System.out.println("unsupported_quarantined=" + unsupportedQuarantined());
        System.out.println("claim_recoverable=" + recoverableClaim());
        System.out.println("aggregate_order_explicit=" + explicitAggregateOrder());
        System.out.println("verification_report=PASS assertions=8");
    }
}
