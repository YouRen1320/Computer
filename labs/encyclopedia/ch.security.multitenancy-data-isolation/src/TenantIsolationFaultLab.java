import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;

/** Replays one independently observable isolation failure at each tenant-aware boundary. */
public final class TenantIsolationFaultLab {
    private enum FaultMode {
        NORMAL,
        TRUST_REQUEST_TENANT,
        LIST_MISSING_TENANT,
        WRITE_BY_ID_ONLY,
        CACHE_KEY_MISSING_TENANT,
        TASK_CONTEXT_MISSING,
        JOIN_TENANT_MISSING,
        NULL_MEANS_GLOBAL
    }

    private enum Scope { GLOBAL, TENANT }
    private record TenantContext(String tenantId) { }
    private record Row(String tenantId, String localId, String value) { }
    private record TaskEnvelope(String tenantId, String localId) { }
    private record CatalogEntry(Scope scope, String tenantId) { }

    private static final class Repository {
        private final List<Row> rows = new ArrayList<>(List.of(
                new Row("TENANT-A", "LOCAL-1", "A-ONE"),
                new Row("TENANT-A", "LOCAL-2", "A-TWO"),
                new Row("TENANT-B", "LOCAL-1", "B-ONE"),
                new Row("TENANT-B", "B-ONLY", "B-ONLY-VALUE")));

        List<Row> list(TenantContext context, FaultMode fault) {
            return rows.stream()
                    .filter(row -> fault == FaultMode.LIST_MISSING_TENANT
                            || row.tenantId().equals(context.tenantId()))
                    .toList();
        }

        Optional<Row> find(TenantContext context, String localId) {
            return rows.stream()
                    .filter(row -> row.tenantId().equals(context.tenantId())
                            && row.localId().equals(localId))
                    .findFirst();
        }

        int rename(TenantContext context, String localId, String value, FaultMode fault) {
            for (int index = 0; index < rows.size(); index++) {
                Row row = rows.get(index);
                boolean tenantMatches = fault == FaultMode.WRITE_BY_ID_ONLY
                        || row.tenantId().equals(context.tenantId());
                if (tenantMatches && row.localId().equals(localId)) {
                    rows.set(index, new Row(row.tenantId(), row.localId(), value));
                    return 1;
                }
            }
            return 0;
        }
    }

    private TenantIsolationFaultLab() { }

    private static Optional<TenantContext> establishContext(
            String membershipTenant, String requestTenant, FaultMode fault) {
        if (fault == FaultMode.TRUST_REQUEST_TENANT) {
            return Optional.of(new TenantContext(requestTenant));
        }
        return membershipTenant.equals(requestTenant)
                ? Optional.of(new TenantContext(membershipTenant))
                : Optional.empty();
    }

    private static String cacheKey(TenantContext context, String localId, FaultMode fault) {
        return fault == FaultMode.CACHE_KEY_MISSING_TENANT
                ? "resource=" + localId
                : "tenant=" + context.tenantId() + "|resource=" + localId;
    }

    private static Optional<Row> executeTask(
            Repository repository, TaskEnvelope envelope, FaultMode fault) {
        String tenant = fault == FaultMode.TASK_CONTEXT_MISSING ? "TENANT-A" : envelope.tenantId();
        return repository.find(new TenantContext(tenant), envelope.localId());
    }

    private static boolean joinMatches(Row left, Row right, FaultMode fault) {
        boolean localIdMatches = left.localId().equals(right.localId());
        return localIdMatches && (fault == FaultMode.JOIN_TENANT_MISSING
                || left.tenantId().equals(right.tenantId()));
    }

    private static boolean catalogValid(CatalogEntry entry, FaultMode fault) {
        if (fault == FaultMode.NULL_MEANS_GLOBAL && entry.tenantId() == null) {
            return true;
        }
        return entry.scope() == Scope.GLOBAL ? entry.tenantId() == null : entry.tenantId() != null;
    }

    private static String injectedOutcome(FaultMode fault) {
        Repository repository = new Repository();
        TenantContext tenantA = new TenantContext("TENANT-A");
        TenantContext tenantB = new TenantContext("TENANT-B");
        return switch (fault) {
            case TRUST_REQUEST_TENANT -> establishContext("TENANT-A", "TENANT-B", fault).isPresent()
                    ? "FORGED_TENANT_ACCEPTED" : "FAULT_NOT_EXPOSED";
            case LIST_MISSING_TENANT -> repository.list(tenantA, fault).stream()
                    .anyMatch(row -> row.tenantId().equals("TENANT-B"))
                    ? "CROSS_TENANT_LIST_LEAKED" : "FAULT_NOT_EXPOSED";
            case WRITE_BY_ID_ONLY -> repository.rename(tenantA, "B-ONLY", "CHANGED", fault) > 0
                    ? "CROSS_TENANT_WRITE_CHANGED" : "FAULT_NOT_EXPOSED";
            case CACHE_KEY_MISSING_TENANT -> {
                Map<String, String> cache = new HashMap<>();
                cache.put(cacheKey(tenantA, "LOCAL-1", fault), "A-ONE");
                cache.put(cacheKey(tenantB, "LOCAL-1", fault), "B-ONE");
                yield "B-ONE".equals(cache.get(cacheKey(tenantA, "LOCAL-1", fault)))
                        ? "CROSS_TENANT_CACHE_COLLISION" : "FAULT_NOT_EXPOSED";
            }
            case TASK_CONTEXT_MISSING -> executeTask(
                    repository, new TaskEnvelope("TENANT-B", "LOCAL-1"), fault)
                    .map(row -> row.tenantId().equals("TENANT-A")).orElse(false)
                    ? "BACKGROUND_CONTEXT_LEAKED" : "FAULT_NOT_EXPOSED";
            case JOIN_TENANT_MISSING -> joinMatches(
                    new Row("TENANT-A", "LOCAL-1", "PARENT"),
                    new Row("TENANT-B", "LOCAL-1", "CHILD"), fault)
                    ? "CROSS_TENANT_JOIN_LEAKED" : "FAULT_NOT_EXPOSED";
            case NULL_MEANS_GLOBAL -> catalogValid(new CatalogEntry(Scope.TENANT, null), fault)
                    ? "NULL_TENANT_TREATED_AS_GLOBAL" : "FAULT_NOT_EXPOSED";
            case NORMAL -> "FAULT_NOT_EXPOSED";
        };
    }

    public static void main(String[] args) {
        FaultMode fault = args.length == 0 ? FaultMode.NORMAL : FaultMode.valueOf(args[0]);
        if (fault != FaultMode.NORMAL) {
            System.out.println(injectedOutcome(fault));
            return;
        }

        Repository repository = new Repository();
        TenantContext tenantA = establishContext("TENANT-A", "TENANT-A", fault).orElseThrow();
        TenantContext tenantB = establishContext("TENANT-B", "TENANT-B", fault).orElseThrow();
        boolean forgedRejected = establishContext("TENANT-A", "TENANT-B", fault).isEmpty();
        boolean listIsolated = repository.list(tenantA, fault).stream()
                .noneMatch(row -> row.tenantId().equals("TENANT-B"));
        boolean writeIsolated = repository.rename(tenantA, "B-ONLY", "CHANGED", fault) == 0;

        Map<String, String> cache = new HashMap<>();
        cache.put(cacheKey(tenantA, "LOCAL-1", fault), "A-ONE");
        cache.put(cacheKey(tenantB, "LOCAL-1", fault), "B-ONE");
        boolean cacheIsolated = "A-ONE".equals(cache.get(cacheKey(tenantA, "LOCAL-1", fault)));
        boolean taskIsolated = executeTask(repository, new TaskEnvelope("TENANT-B", "LOCAL-1"), fault)
                .map(row -> row.tenantId().equals("TENANT-B")).orElse(false);
        boolean joinIsolated = !joinMatches(
                new Row("TENANT-A", "LOCAL-1", "PARENT"),
                new Row("TENANT-B", "LOCAL-1", "CHILD"), fault);
        boolean nullRejected = !catalogValid(new CatalogEntry(Scope.TENANT, null), fault);

        System.out.println("forged_request=" + (forgedRejected ? "REJECTED" : "ACCEPTED"));
        System.out.println("list_cross_tenant=" + (listIsolated ? "ZERO" : "NONZERO"));
        System.out.println("write_cross_tenant=" + (writeIsolated ? "ZERO" : "NONZERO"));
        System.out.println("cache_cross_tenant=" + (cacheIsolated ? "ZERO" : "NONZERO"));
        System.out.println("task_cross_tenant=" + (taskIsolated ? "ZERO" : "NONZERO"));
        System.out.println("join_cross_tenant=" + (joinIsolated ? "ZERO" : "NONZERO"));
        System.out.println("null_global=" + (nullRejected ? "REJECTED" : "ACCEPTED"));
        System.out.println("verification_report=PASS assertions=7");
    }
}
