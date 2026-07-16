import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Set;

public final class DomainEventsOutboxExample {
    private record Event(String eventId, String eventType, int version, String aggregateId, long aggregateVersion) { }

    private static final class Store {
        private String workOrderState = "RESOLVED";
        private final List<Event> outbox = new ArrayList<>();

        boolean close(String eventId, boolean failOutbox) {
            String nextState = "CLOSED";
            List<Event> pending = new ArrayList<>(outbox);
            Event event = new Event(eventId, "WorkOrderClosed.v1", 1, "wo-42", 8L);
            if (failOutbox) {
                return false;
            }
            pending.add(event);
            workOrderState = nextState;
            outbox.clear();
            outbox.addAll(pending);
            return true;
        }

        String state() {
            return workOrderState;
        }

        List<Event> outbox() {
            return List.copyOf(outbox);
        }
    }

    private static final class Consumer {
        private final Set<String> completed = new HashSet<>();
        private int effects;

        String accept(Event event) {
            if (event.version() != 1 || !"WorkOrderClosed.v1".equals(event.eventType())) {
                return "QUARANTINED";
            }
            if (completed.add(event.eventId())) {
                effects++;
            }
            return "APPLIED";
        }

        int effects() {
            return effects;
        }
    }

    public static void main(String[] args) {
        Store store = new Store();
        store.close("evt-closed-0001", true);
        System.out.println("rollback_state=" + store.state());
        System.out.println("rollback_outbox=" + store.outbox().size());

        store.close("evt-closed-0001", false);
        Event event = store.outbox().getFirst();
        System.out.println("commit_state=" + store.state());
        System.out.println("commit_outbox=" + store.outbox().size());
        System.out.println("event_type=" + event.eventType());
        System.out.println("event_version=" + event.version());

        Consumer consumer = new Consumer();
        List<String> deliveredIds = new ArrayList<>();
        deliveredIds.add(event.eventId());
        consumer.accept(event);
        // The relay crashes after delivery and retries the same persisted event.
        deliveredIds.add(event.eventId());
        consumer.accept(event);
        System.out.println("relay_attempts=" + deliveredIds.size());
        System.out.println("delivery_ids_stable=" + (deliveredIds.stream().distinct().count() == 1L));
        System.out.println("consumer_effects=" + consumer.effects());

        Event unsupported = new Event("evt-closed-0002", "WorkOrderClosed.v2", 2, "wo-42", 9L);
        System.out.println("unsupported_version=" + consumer.accept(unsupported));
        System.out.println("exactly_once_claim=false");
    }
}
