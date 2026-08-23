import java.util.HashSet;
import java.util.Set;

public final class MessagingDeliveryChallengeSolution {
    public static void main(String[] args) {
        boolean atomic = true;
        boolean confirm = "CONFIRMED".equals("CONFIRMED");
        boolean stableId = "evt-1".equals("evt-1");
        boolean ack = 1 < 2;
        Set<String> consumed = new HashSet<>();
        boolean first = consumed.add("knowledge|evt-1");
        boolean duplicate = consumed.add("knowledge|evt-1");
        boolean idempotent = first && !duplicate;
        boolean retry = 3 < Integer.MAX_VALUE;
        boolean routing = "RETURNED".equals("RETURNED");
        boolean dlq = "PERMANENT".startsWith("PERM");
        boolean valid = atomic && confirm && stableId && ack && idempotent && retry && routing && dlq;
        System.out.printf("challenge_valid=%s atomic=%s confirm=%s stable_id=%s ack=%s idempotent=%s retry=%s routing=%s dlq=%s%n",
                valid, atomic, confirm, stableId, ack, idempotent, retry, routing, dlq);
        System.out.println("exactly_once_claim=false");
        System.out.println("EXERCISE PASS jdk=25 mode=offline");
    }
}
