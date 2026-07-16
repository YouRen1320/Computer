import java.util.EnumSet;
import java.util.Set;

/** Green reference for attributable audit facts and privacy-minimized projections. */
public final class AuditPrivacyChallengeSolution {
    enum DetailField { CHANGE_SUMMARY, REASON_CODE, MASKED_CONTACT, AUTHENTICATOR, FULL_CONTACT }
    enum Result { SUCCESS, DENIED, FAILURE }

    private static final Set<DetailField> ALLOWED = Set.copyOf(EnumSet.of(
            DetailField.CHANGE_SUMMARY, DetailField.REASON_CODE, DetailField.MASKED_CONTACT));

    private AuditPrivacyChallengeSolution() { }

    public static void main(String[] args) {
        require(allowedDetails(Set.of(DetailField.CHANGE_SUMMARY, DetailField.REASON_CODE)),
                "SAFE_DETAILS_REJECTED");
        require(!allowedDetails(Set.of(DetailField.AUTHENTICATOR)), "SECRET_FIELD_ACCEPTED");
        require(requiredIdentity("ACTOR-7", "TENANT-A", "WORK-9"), "IDENTITY_REJECTED");
        require(!requiredIdentity("", "TENANT-A", "WORK-9"), "MISSING_ACTOR_ACCEPTED");
        require(!requiredIdentity("ACTOR-7", "", "WORK-9"), "MISSING_TENANT_ACCEPTED");
        require(truthfulResult(true, Result.SUCCESS), "COMMITTED_SUCCESS_REJECTED");
        require(!truthfulResult(false, Result.SUCCESS), "ROLLED_BACK_ACTION_MARKED_SUCCESS");
        require(truthfulResult(false, Result.DENIED), "DENIAL_FACT_REJECTED");
        require(appendOnly(false, false), "NEW_APPEND_REJECTED");
        require(!appendOnly(true, true), "AUDIT_EVENT_OVERWRITTEN");
        require(tenantVisible("TENANT-A", "TENANT-A"), "OWN_AUDIT_HIDDEN");
        require(!tenantVisible("TENANT-A", "TENANT-B"), "CROSS_TENANT_AUDIT_VISIBLE");
        require(traceIsCorrelationOnly("ACTOR-7", "TRACE-1"), "VALID_TRACE_REJECTED");
        require(!traceIsCorrelationOnly("TRACE-1", "TRACE-1"), "TRACE_ID_USED_AS_ACTOR");
        require(maskedDisplay("operator@example.test", "op***@example.test"),
                "MASKED_DISPLAY_REJECTED");
        require(!maskedDisplay("operator@example.test", "operator@example.test"),
                "FULL_CONTACT_EXPOSED");

        System.out.println("challenge_valid=true details=true identity=true truth=true append=true tenant=true trace=true mask=true");
        System.out.println("EXERCISE PASS jdk=25 mode=offline");
    }

    static boolean allowedDetails(Set<DetailField> fields) {
        return fields != null && ALLOWED.containsAll(fields);
    }

    static boolean requiredIdentity(String actor, String tenant, String target) {
        return nonblank(actor) && nonblank(tenant) && nonblank(target);
    }

    static boolean truthfulResult(boolean businessCommitted, Result result) {
        return result != Result.SUCCESS || businessCommitted;
    }

    static boolean appendOnly(boolean eventAlreadyExists, boolean overwriteRequested) {
        return !eventAlreadyExists || !overwriteRequested;
    }

    static boolean tenantVisible(String contextTenant, String eventTenant) {
        return contextTenant != null && contextTenant.equals(eventTenant);
    }

    static boolean traceIsCorrelationOnly(String actor, String trace) {
        return nonblank(actor) && nonblank(trace) && !actor.equals(trace);
    }

    static boolean maskedDisplay(String original, String projection) {
        return nonblank(original) && nonblank(projection)
                && !original.equals(projection) && projection.contains("***");
    }

    private static boolean nonblank(String value) {
        return value != null && !value.isBlank();
    }

    private static void require(boolean condition, String marker) {
        if (!condition) {
            throw new IllegalStateException(marker);
        }
    }
}
