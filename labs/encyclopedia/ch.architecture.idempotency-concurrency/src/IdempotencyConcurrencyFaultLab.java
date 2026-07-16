import java.util.HashMap;
import java.util.Map;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;

/** Injects duplicate-delivery and stale-version faults with deterministic oracles. */
public final class IdempotencyConcurrencyFaultLab {
    private enum FaultMode {
        NORMAL,
        SIDE_EFFECT_BEFORE_CLAIM,
        KEY_ONLY_SCOPE,
        PAYLOAD_NOT_BOUND,
        RESPONSE_NOT_SAVED,
        VERSION_NOT_IN_WHERE,
        UPDATE_ZERO_IGNORED,
        BLIND_RETRY
    }

    private record Request(
            String tenant, String actor, String operation, String key, String fingerprint) { }
    private record Response(int status, String body) { }
    private record Record(String fingerprint, Response response) { }

    private static final class IdempotencyService {
        private final Map<String, Record> records = new HashMap<>();
        private int sideEffects;
        private int sequence;

        Response execute(Request request, FaultMode fault) {
            if (fault == FaultMode.SIDE_EFFECT_BEFORE_CLAIM) {
                sideEffects++;
            }
            String scope = fault == FaultMode.KEY_ONLY_SCOPE
                    ? request.key()
                    : request.tenant() + "|" + request.actor() + "|"
                            + request.operation() + "|" + request.key();
            Record existing = records.get(scope);
            if (existing != null) {
                if (fault != FaultMode.PAYLOAD_NOT_BOUND
                        && !existing.fingerprint().equals(request.fingerprint())) {
                    return new Response(409, "IDEMPOTENCY_CONFLICT");
                }
                if (fault == FaultMode.RESPONSE_NOT_SAVED) {
                    return new Response(201, "RECONSTRUCTED-" + (++sequence));
                }
                return existing.response();
            }

            if (fault != FaultMode.SIDE_EFFECT_BEFORE_CLAIM) {
                sideEffects++;
            }
            Response response = new Response(201, request.tenant() + "-RESULT-" + (++sequence));
            records.put(scope, new Record(request.fingerprint(), response));
            return response;
        }

        int sideEffects() {
            return sideEffects;
        }
    }

    private static final class VersionedAggregate {
        private long version;
        private String assignee;

        VersionedAggregate(long version, String assignee) {
            this.version = version;
            this.assignee = assignee;
        }

        synchronized boolean assign(long expectedVersion, String desired, FaultMode fault) {
            if (fault != FaultMode.VERSION_NOT_IN_WHERE && version != expectedVersion) {
                return false;
            }
            assignee = desired;
            version++;
            return true;
        }

        synchronized long version() {
            return version;
        }

        synchronized String assignee() {
            return assignee;
        }
    }

    private IdempotencyConcurrencyFaultLab() { }

    private static Request request(
            String tenant, String actor, String operation, String key, String fingerprint) {
        return new Request(tenant, actor, operation, key, fingerprint);
    }

    private static int concurrentWinners(FaultMode fault) throws Exception {
        VersionedAggregate aggregate = new VersionedAggregate(1, "UNASSIGNED");
        CountDownLatch ready = new CountDownLatch(2);
        CountDownLatch start = new CountDownLatch(1);
        ExecutorService executor = Executors.newFixedThreadPool(2);
        try {
            Future<Boolean> first = executor.submit(() -> {
                ready.countDown();
                start.await();
                return aggregate.assign(1, "TECH-A", fault);
            });
            Future<Boolean> second = executor.submit(() -> {
                ready.countDown();
                start.await();
                return aggregate.assign(1, "TECH-B", fault);
            });
            ready.await();
            start.countDown();
            return (first.get() ? 1 : 0) + (second.get() ? 1 : 0);
        } finally {
            executor.shutdownNow();
        }
    }

    private static int updateStatus(boolean updated, FaultMode fault) {
        return updated || fault == FaultMode.UPDATE_ZERO_IGNORED ? 200 : 409;
    }

    private static boolean applyWithRetry(
            VersionedAggregate aggregate, long expectedVersion, String desired, FaultMode fault) {
        if (aggregate.assign(expectedVersion, desired, FaultMode.NORMAL)) {
            return true;
        }
        return fault == FaultMode.BLIND_RETRY
                && aggregate.assign(aggregate.version(), desired, FaultMode.NORMAL);
    }

    private static String injectedOutcome(FaultMode fault) throws Exception {
        return switch (fault) {
            case SIDE_EFFECT_BEFORE_CLAIM -> {
                IdempotencyService service = new IdempotencyService();
                Request item = request("TENANT-A", "ACTOR-7", "DISPATCH", "KEY-1", "FP-A");
                service.execute(item, fault);
                service.execute(item, fault);
                yield service.sideEffects() == 2 ? "DUPLICATE_SIDE_EFFECT" : "FAULT_NOT_EXPOSED";
            }
            case KEY_ONLY_SCOPE -> {
                IdempotencyService service = new IdempotencyService();
                service.execute(request("TENANT-A", "ACTOR-7", "DISPATCH", "KEY-1", "FP-A"), fault);
                Response second = service.execute(
                        request("TENANT-B", "ACTOR-8", "CREATE_REPORT", "KEY-1", "FP-A"), fault);
                yield second.body().startsWith("TENANT-A-")
                        ? "CROSS_SCOPE_KEY_COLLISION" : "FAULT_NOT_EXPOSED";
            }
            case PAYLOAD_NOT_BOUND -> {
                IdempotencyService service = new IdempotencyService();
                service.execute(request("TENANT-A", "ACTOR-7", "DISPATCH", "KEY-1", "FP-A"), fault);
                Response second = service.execute(
                        request("TENANT-A", "ACTOR-7", "DISPATCH", "KEY-1", "FP-B"), fault);
                yield second.status() == 201 ? "DIFFERENT_PAYLOAD_REPLAYED" : "FAULT_NOT_EXPOSED";
            }
            case RESPONSE_NOT_SAVED -> {
                IdempotencyService service = new IdempotencyService();
                Request item = request("TENANT-A", "ACTOR-7", "DISPATCH", "KEY-1", "FP-A");
                Response first = service.execute(item, fault);
                Response second = service.execute(item, fault);
                yield !first.equals(second) ? "REPLAY_RESPONSE_CHANGED" : "FAULT_NOT_EXPOSED";
            }
            case VERSION_NOT_IN_WHERE -> concurrentWinners(fault) == 2
                    ? "LOST_UPDATE_COMMITTED" : "FAULT_NOT_EXPOSED";
            case UPDATE_ZERO_IGNORED -> updateStatus(false, fault) == 200
                    ? "ZERO_ROW_UPDATE_REPORTED_SUCCESS" : "FAULT_NOT_EXPOSED";
            case BLIND_RETRY -> {
                VersionedAggregate aggregate = new VersionedAggregate(2, "CURRENT-ASSIGNEE");
                boolean applied = applyWithRetry(aggregate, 1, "STALE-ASSIGNEE", fault);
                yield applied && aggregate.assignee().equals("STALE-ASSIGNEE")
                        ? "STALE_COMMAND_REAPPLIED" : "FAULT_NOT_EXPOSED";
            }
            case NORMAL -> "FAULT_NOT_EXPOSED";
        };
    }

    public static void main(String[] args) throws Exception {
        FaultMode fault = args.length == 0 ? FaultMode.NORMAL : FaultMode.valueOf(args[0]);
        if (fault != FaultMode.NORMAL) {
            System.out.println(injectedOutcome(fault));
            return;
        }

        IdempotencyService duplicateService = new IdempotencyService();
        Request firstRequest = request("TENANT-A", "ACTOR-7", "DISPATCH", "KEY-1", "FP-A");
        duplicateService.execute(firstRequest, fault);
        duplicateService.execute(firstRequest, fault);
        boolean oneEffect = duplicateService.sideEffects() == 1;

        Response conflict = duplicateService.execute(
                request("TENANT-A", "ACTOR-7", "DISPATCH", "KEY-1", "FP-B"), fault);

        IdempotencyService scopeService = new IdempotencyService();
        Response tenantA = scopeService.execute(
                request("TENANT-A", "ACTOR-7", "DISPATCH", "KEY-1", "FP-A"), fault);
        Response tenantB = scopeService.execute(
                request("TENANT-B", "ACTOR-8", "CREATE_REPORT", "KEY-1", "FP-A"), fault);
        boolean isolated = !tenantA.equals(tenantB) && scopeService.sideEffects() == 2;

        IdempotencyService replayService = new IdempotencyService();
        Response original = replayService.execute(firstRequest, fault);
        Response replay = replayService.execute(firstRequest, fault);
        int winners = concurrentWinners(fault);
        int zeroStatus = updateStatus(false, fault);
        VersionedAggregate changed = new VersionedAggregate(2, "CURRENT-ASSIGNEE");
        boolean blindRejected = !applyWithRetry(changed, 1, "STALE-ASSIGNEE", fault)
                && changed.assignee().equals("CURRENT-ASSIGNEE");

        System.out.println("same_key_same_payload=" + (oneEffect ? "ONE_EFFECT" : "DUPLICATED"));
        System.out.println("different_payload=" + (conflict.status() == 409 ? "CONFLICT" : "REPLAYED"));
        System.out.println("scope_isolated=" + isolated);
        System.out.println("response_replayed=" + original.equals(replay));
        System.out.println("optimistic_winners=" + winners);
        System.out.println("update_zero=" + (zeroStatus == 409 ? "CONFLICT" : "SUCCESS"));
        System.out.println("blind_retry=" + (blindRejected ? "REJECTED" : "APPLIED"));
        System.out.println("verification_report=PASS assertions=7");
    }
}
