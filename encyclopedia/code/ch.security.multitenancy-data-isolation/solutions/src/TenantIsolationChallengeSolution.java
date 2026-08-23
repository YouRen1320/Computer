import java.util.Optional;

/** Green reference for trusted tenant identity and tenant-aware data boundaries. */
public final class TenantIsolationChallengeSolution {
    enum Scope { GLOBAL, TENANT }

    private TenantIsolationChallengeSolution() { }

    public static void main(String[] args) {
        require(trustedTenant("TENANT-A", "TENANT-A").orElseThrow().equals("TENANT-A"),
                "VALID_MEMBERSHIP_REJECTED");
        require(trustedTenant("TENANT-A", "TENANT-B").isEmpty(), "FORGED_TENANT_ACCEPTED");
        require(scopedRow("TENANT-A", "TENANT-A"), "OWN_ROW_REJECTED");
        require(!scopedRow("TENANT-A", "TENANT-B"), "CROSS_TENANT_ROW_VISIBLE");
        require(scopedWrite("TENANT-A", "TENANT-A"), "OWN_WRITE_REJECTED");
        require(!scopedWrite("TENANT-A", "TENANT-B"), "CROSS_TENANT_WRITE_ALLOWED");
        require(cacheKeyIncludesTenant("tenant=TENANT-A|resource=LOCAL-1", "TENANT-A"),
                "SCOPED_CACHE_KEY_REJECTED");
        require(!cacheKeyIncludesTenant("resource=LOCAL-1", "TENANT-A"),
                "UNSCOPED_CACHE_KEY_ACCEPTED");
        require(taskContextPresent("TENANT-A"), "TASK_CONTEXT_REJECTED");
        require(!taskContextPresent(""), "MISSING_TASK_CONTEXT_ACCEPTED");
        require(joinTenantMatches("TENANT-A", "TENANT-A"), "OWN_JOIN_REJECTED");
        require(!joinTenantMatches("TENANT-A", "TENANT-B"), "CROSS_TENANT_JOIN_ALLOWED");
        require(validCatalog(Scope.GLOBAL, null), "GLOBAL_CATALOG_REJECTED");
        require(validCatalog(Scope.TENANT, "TENANT-A"), "TENANT_CATALOG_REJECTED");
        require(!validCatalog(Scope.TENANT, null), "NULL_TENANT_TREATED_AS_GLOBAL");

        System.out.println("challenge_valid=true context=true query=true write=true cache=true task=true join=true catalog=true");
        System.out.println("EXERCISE PASS jdk=25 mode=offline");
    }

    static Optional<String> trustedTenant(String membershipTenant, String requestTenant) {
        return membershipTenant != null && membershipTenant.equals(requestTenant)
                ? Optional.of(membershipTenant) : Optional.empty();
    }

    static boolean scopedRow(String contextTenant, String rowTenant) {
        return contextTenant != null && contextTenant.equals(rowTenant);
    }

    static boolean scopedWrite(String contextTenant, String rowTenant) {
        return contextTenant != null && contextTenant.equals(rowTenant);
    }

    static boolean cacheKeyIncludesTenant(String key, String tenant) {
        return key != null && tenant != null && key.contains("tenant=" + tenant + "|");
    }

    static boolean taskContextPresent(String envelopeTenant) {
        return envelopeTenant != null && !envelopeTenant.isBlank();
    }

    static boolean joinTenantMatches(String leftTenant, String rightTenant) {
        return leftTenant != null && leftTenant.equals(rightTenant);
    }

    static boolean validCatalog(Scope scope, String tenant) {
        return scope == Scope.GLOBAL ? tenant == null : tenant != null && !tenant.isBlank();
    }

    private static void require(boolean condition, String marker) {
        if (!condition) {
            throw new IllegalStateException(marker);
        }
    }
}
