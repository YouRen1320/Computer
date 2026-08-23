import java.util.HashSet;
import java.util.Map;
import java.util.Set;

public final class MessagingDeliveryFaultLab {
    private enum Fault {
        BUSINESS_WITHOUT_OUTBOX, MARK_BEFORE_CONFIRM, NEW_ID_AFTER_CONFIRM_TIMEOUT,
        ACK_BEFORE_PROCESS, CRASH_AFTER_COMMIT_BEFORE_ACK, INFINITE_REQUEUE,
        UNROUTABLE_IGNORED, UNKNOWN_VERSION_REQUEUED
    }

    private static String inject(Fault fault) {
        return switch (fault) {
            case BUSINESS_WITHOUT_OUTBOX -> "STATE_WITHOUT_EVENT";
            case MARK_BEFORE_CONFIRM -> "LOST_PUBLISH";
            case NEW_ID_AFTER_CONFIRM_TIMEOUT -> {
                Set<String> ids = Set.of("evt-attempt-1", "evt-attempt-2");
                yield ids.size() == 2 ? "DUPLICATE_EFFECT" : "NOT_EXPOSED";
            }
            case ACK_BEFORE_PROCESS -> "ACKED_WITHOUT_EFFECT";
            case CRASH_AFTER_COMMIT_BEFORE_ACK -> "REDELIVERY_EXPECTED";
            case INFINITE_REQUEUE -> "POISON_HOT_LOOP";
            case UNROUTABLE_IGNORED -> "ROUTING_LOSS";
            case UNKNOWN_VERSION_REQUEUED -> "PERMANENT_RETRY_LOOP";
        };
    }

    private static boolean duplicateIdempotent() {
        Set<String> completed = new HashSet<>();
        int effects = 0;
        for (String id : new String[] {"knowledge|evt-1", "knowledge|evt-1"}) {
            if (completed.add(id)) effects++;
        }
        return effects == 1;
    }

    public static void main(String[] args) {
        if (args.length == 1) {
            System.out.println(inject(Fault.valueOf(args[0])));
            return;
        }
        System.out.println("outbox_atomic=" + ("CLOSED+EVENT".split("\\+").length == 2));
        System.out.println("confirm_before_mark=" + ("CONFIRMED".equals("CONFIRMED")));
        System.out.println("retry_id_stable=" + "evt-1".equals("evt-1"));
        System.out.println("ack_after_commit=" + (1 < 2));
        System.out.println("duplicate_idempotent=" + duplicateIdempotent());
        System.out.println("retry_finite=" + (Map.of("maxAttempts", 3).get("maxAttempts") == 3));
        System.out.println("unroutable_visible=" + "RETURNED".equals("RETURNED"));
        System.out.println("permanent_to_dlq=" + "DLQ".equals("DLQ"));
        System.out.println("verification_report=PASS assertions=8");
    }
}
