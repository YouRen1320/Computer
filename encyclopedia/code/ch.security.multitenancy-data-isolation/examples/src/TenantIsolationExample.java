import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;

/** Demonstrates explicit tenant constraints beyond the HTTP request boundary. */
public final class TenantIsolationExample {
    private enum Scope { GLOBAL, TENANT }
    private record TenantContext(String tenantId, String dataScope) { }
    private record Row(String tenantId, String localId, String value) { }
    private record TaskEnvelope(String tenantId, String localId) { }
    private record CatalogEntry(Scope scope, String tenantId) { }

    private static final class Repository {
        private final List<Row> rows = new ArrayList<>(List.of(
                new Row("TENANT-A", "LOCAL-1", "A-ONE"),
                new Row("TENANT-A", "LOCAL-2", "A-TWO"),
                new Row("TENANT-B", "LOCAL-1", "B-ONE"),
                new Row("TENANT-B", "B-ONLY", "B-ONLY-VALUE")));

        List<Row> list(TenantContext context) {
            return rows.stream().filter(row -> row.tenantId().equals(context.tenantId())).toList();
        }

        Optional<Row> find(TenantContext context, String localId) {
            return rows.stream()
                    .filter(row -> row.tenantId().equals(context.tenantId()) && row.localId().equals(localId))
                    .findFirst();
        }

        int rename(TenantContext context, String localId, String value) {
            for (int index = 0; index < rows.size(); index++) {
                Row row = rows.get(index);
                if (row.tenantId().equals(context.tenantId()) && row.localId().equals(localId)) {
                    rows.set(index, new Row(row.tenantId(), row.localId(), value));
                    return 1;
                }
            }
            return 0;
        }
    }

    private TenantIsolationExample() { }

    private static Optional<TenantContext> establishContext(String membershipTenant, String requestTenant) {
        return membershipTenant.equals(requestTenant)
                ? Optional.of(new TenantContext(membershipTenant, "ORGANIZATION"))
                : Optional.empty();
    }

    private static String cacheKey(TenantContext context, String localId) {
        return "tenant=" + context.tenantId() + "|scope=" + context.dataScope() + "|resource=" + localId;
    }

    private static Optional<Row> executeTask(Repository repository, TaskEnvelope envelope) {
        return repository.find(new TenantContext(envelope.tenantId(), "ORGANIZATION"), envelope.localId());
    }

    private static boolean catalogValid(CatalogEntry entry) {
        return entry.scope() == Scope.GLOBAL ? entry.tenantId() == null : entry.tenantId() != null;
    }

    public static void main(String[] args) {
        Repository repository = new Repository();
        TenantContext tenantA = establishContext("TENANT-A", "TENANT-A").orElseThrow();
        TenantContext tenantB = establishContext("TENANT-B", "TENANT-B").orElseThrow();
        boolean forgedRejected = establishContext("TENANT-A", "TENANT-B").isEmpty();
        boolean crossRead = repository.find(tenantA, "B-ONLY").isPresent();
        boolean crossWrite = repository.rename(tenantA, "B-ONLY", "FORGED") > 0;

        Map<String, String> cache = new HashMap<>();
        cache.put(cacheKey(tenantA, "LOCAL-1"), repository.find(tenantA, "LOCAL-1").orElseThrow().value());
        cache.put(cacheKey(tenantB, "LOCAL-1"), repository.find(tenantB, "LOCAL-1").orElseThrow().value());
        boolean cacheIsolated = "A-ONE".equals(cache.get(cacheKey(tenantA, "LOCAL-1")))
                && "B-ONE".equals(cache.get(cacheKey(tenantB, "LOCAL-1")));
        boolean taskIsolated = executeTask(repository, new TaskEnvelope("TENANT-B", "LOCAL-1"))
                .map(row -> row.value().equals("B-ONE")).orElse(false);
        boolean catalogExplicit = catalogValid(new CatalogEntry(Scope.GLOBAL, null))
                && catalogValid(new CatalogEntry(Scope.TENANT, "TENANT-A"))
                && !catalogValid(new CatalogEntry(Scope.TENANT, null));

        System.out.println("trusted_context=" + tenantA.tenantId());
        System.out.println("forged_request_rejected=" + forgedRejected);
        System.out.println("tenant_a_rows=" + repository.list(tenantA).size());
        System.out.println("cross_tenant_read=" + crossRead);
        System.out.println("cross_tenant_write=" + crossWrite);
        System.out.println("cache_isolated=" + cacheIsolated);
        System.out.println("background_task_isolated=" + taskIsolated);
        System.out.println("global_catalog_explicit=" + catalogExplicit);
        System.out.println("secret_material_printed=false");
    }
}
