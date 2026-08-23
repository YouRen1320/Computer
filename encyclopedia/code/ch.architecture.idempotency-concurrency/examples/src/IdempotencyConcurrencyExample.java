import java.util.HashMap;
import java.util.Map;

/** Demonstrates response replay before optimistic-version evaluation. */
public final class IdempotencyConcurrencyExample {
    private record Request(
            String tenant, String actor, String operation, String key,
            String fingerprint, long expectedVersion, String assignee) { }
    private record Response(int status, String code, long version) { }
    private record IdempotencyRecord(String fingerprint, Response response) { }

    private static final class WorkOrder {
        private long version = 1;
        private String assignee = "UNASSIGNED";
        private int sideEffects;

        boolean assign(long expectedVersion, String newAssignee) {
            if (version != expectedVersion) {
                return false;
            }
            assignee = newAssignee;
            version++;
            sideEffects++;
            return true;
        }

        long version() {
            return version;
        }

        String assignee() {
            return assignee;
        }

        int sideEffects() {
            return sideEffects;
        }
    }

    private static final class DispatchService {
        private final WorkOrder workOrder;
        private final Map<String, IdempotencyRecord> records = new HashMap<>();

        DispatchService(WorkOrder workOrder) {
            this.workOrder = workOrder;
        }

        Response dispatch(Request request) {
            String scope = request.tenant() + "|" + request.actor() + "|"
                    + request.operation() + "|" + request.key();
            IdempotencyRecord existing = records.get(scope);
            if (existing != null) {
                return existing.fingerprint().equals(request.fingerprint())
                        ? existing.response()
                        : new Response(409, "IDEMPOTENCY_CONFLICT", workOrder.version());
            }

            Response response;
            if (workOrder.assign(request.expectedVersion(), request.assignee())) {
                response = new Response(201, "ASSIGNED", workOrder.version());
            } else {
                response = new Response(409, "VERSION_CONFLICT", workOrder.version());
            }
            records.put(scope, new IdempotencyRecord(request.fingerprint(), response));
            return response;
        }
    }

    private IdempotencyConcurrencyExample() { }

    public static void main(String[] args) {
        WorkOrder workOrder = new WorkOrder();
        DispatchService service = new DispatchService(workOrder);
        Request firstRequest = new Request("TENANT-A", "ACTOR-7", "DISPATCH", "KEY-1",
                "FP-TEAM-A", 1, "TECH-A");
        Response first = service.dispatch(firstRequest);
        Response replay = service.dispatch(firstRequest);
        Response keyReuse = service.dispatch(new Request("TENANT-A", "ACTOR-7", "DISPATCH",
                "KEY-1", "FP-TEAM-B", 1, "TECH-B"));
        Response stale = service.dispatch(new Request("TENANT-A", "ACTOR-8", "DISPATCH",
                "KEY-2", "FP-TEAM-B", 1, "TECH-B"));

        System.out.println("first_status=" + first.status());
        System.out.println("replay_same_response=" + first.equals(replay));
        System.out.println("side_effects=" + workOrder.sideEffects());
        System.out.println("key_reuse_conflict=" + keyReuse.status());
        System.out.println("optimistic_winner=" + ("TECH-A".equals(workOrder.assignee()) ? 1 : 0));
        System.out.println("stale_writer=" + stale.status());
        System.out.println("version=" + workOrder.version());
        System.out.println("exactly_once_claim=false");
    }
}
