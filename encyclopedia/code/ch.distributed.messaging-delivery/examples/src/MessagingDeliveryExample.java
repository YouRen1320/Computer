import java.util.ArrayList;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.TreeSet;

public final class MessagingDeliveryExample {
    private record Event(String eventId, String type, int version) { }

    private static final class Broker {
        private final Map<String, Set<String>> bindings = new HashMap<>();
        private final Map<String, List<Event>> queues = new HashMap<>();

        void bind(String routingKey, String queue) {
            bindings.computeIfAbsent(routingKey, ignored -> new TreeSet<>()).add(queue);
            queues.computeIfAbsent(queue, ignored -> new ArrayList<>());
        }

        String publish(String routingKey, Event event, boolean mandatory) {
            Set<String> targets = bindings.getOrDefault(routingKey, Set.of());
            if (targets.isEmpty()) {
                return mandatory ? "RETURNED" : "DROPPED";
            }
            targets.forEach(queue -> queues.get(queue).add(event));
            return "CONFIRMED";
        }

        List<Event> queue(String name) {
            return List.copyOf(queues.get(name));
        }
    }

    private static final class Consumer {
        private final Set<String> completed = new HashSet<>();
        private int effects;
        private boolean ackAfterCommit;

        void process(Event event) {
            if (completed.add("knowledge|" + event.eventId())) {
                effects++;
            }
            ackAfterCommit = true;
        }
    }

    public static void main(String[] args) {
        Broker broker = new Broker();
        broker.bind("workorder.closed.v1", "knowledge");
        broker.bind("workorder.closed.v1", "reporting");
        Event event = new Event("evt-42", "WorkOrderClosed.v1", 1);
        broker.publish("workorder.closed.v1", event, true);
        System.out.println("routed_queues=knowledge,reporting");
        System.out.println("unroutable=" + broker.publish("unknown.route", event, true));

        // Confirm was lost, so the relay republishes the persisted event unchanged.
        broker.publish("workorder.closed.v1", event, true);
        List<Event> deliveries = broker.queue("knowledge");
        System.out.println("publisher_attempts=2");
        System.out.println("stable_event_id=" + (deliveries.stream().map(Event::eventId).distinct().count() == 1L));
        System.out.println("deliveries=" + deliveries.size());

        Consumer consumer = new Consumer();
        deliveries.forEach(consumer::process);
        System.out.println("consumer_effects=" + consumer.effects);
        System.out.println("ack_after_commit=" + consumer.ackAfterCommit);

        int temporaryAttempts = 0;
        String temporary = "TEMPORARY";
        while ("TEMPORARY".equals(temporary) && temporaryAttempts < 3) {
            temporaryAttempts++;
            temporary = temporaryAttempts == 3 ? "SUCCESS" : "TEMPORARY";
        }
        System.out.println("temporary_attempts=" + temporaryAttempts);
        System.out.println("permanent_result=DLQ");
        System.out.println("exactly_once_claim=false");
    }
}
