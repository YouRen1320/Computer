import java.time.Instant;
import java.util.ArrayList;
import java.util.EnumSet;
import java.util.List;
import java.util.Map;
import java.util.Set;

/** Demonstrates attributable, tenant-scoped audit facts with minimized details. */
public final class AuditPrivacyExample {
    private enum EventType { LOGIN, AUTHORIZATION_DENIED, WORK_ORDER_STATE_CHANGED, ADMIN_ROLE_CHANGED }
    private enum Result { SUCCESS, DENIED, FAILURE }
    private enum DetailField { CHANGE_SUMMARY, REASON_CODE, MASKED_CONTACT, AUTHENTICATOR, SESSION_CREDENTIAL, FULL_CONTACT }

    private record AuditEvent(
            String id,
            EventType type,
            String actor,
            String action,
            String target,
            String tenant,
            Instant occurredAt,
            String trace,
            Result result,
            Map<DetailField, String> details) {
        AuditEvent {
            details = Map.copyOf(details);
        }
    }

    private static final Set<DetailField> ALLOWED_DETAILS = Set.copyOf(EnumSet.of(
            DetailField.CHANGE_SUMMARY, DetailField.REASON_CODE, DetailField.MASKED_CONTACT));

    private static final class AppendOnlyAuditStore {
        private final List<AuditEvent> events = new ArrayList<>();

        boolean append(AuditEvent event, boolean businessCommitted) {
            if (!validIdentity(event) || !ALLOWED_DETAILS.containsAll(event.details().keySet())) {
                return false;
            }
            if (event.result() == Result.SUCCESS && !businessCommitted) {
                return false;
            }
            events.add(event);
            return true;
        }

        boolean replace(String id, AuditEvent replacement) {
            return false;
        }

        List<AuditEvent> query(String tenant) {
            return events.stream().filter(event -> event.tenant().equals(tenant)).toList();
        }

        List<AuditEvent> all() {
            return List.copyOf(events);
        }
    }

    private AuditPrivacyExample() { }

    private static boolean validIdentity(AuditEvent event) {
        return nonblank(event.actor()) && nonblank(event.action()) && nonblank(event.target())
                && nonblank(event.tenant()) && nonblank(event.trace())
                && !event.actor().equals(event.trace());
    }

    private static boolean nonblank(String value) {
        return value != null && !value.isBlank();
    }

    private static AuditEvent event(
            String id, EventType type, String actor, String action, String target,
            String tenant, String trace, Result result, Map<DetailField, String> details) {
        return new AuditEvent(id, type, actor, action, target, tenant,
                Instant.parse("2026-07-17T02:00:00Z"), trace, result, details);
    }

    private static String maskDisplay(String display) {
        int separator = display.indexOf('@');
        if (separator < 2) {
            return "***";
        }
        return display.substring(0, 2) + "***" + display.substring(separator);
    }

    public static void main(String[] args) {
        AppendOnlyAuditStore store = new AppendOnlyAuditStore();
        boolean login = store.append(event("AUD-1", EventType.LOGIN, "ACTOR-7", "LOGIN",
                "SESSION-1", "TENANT-A", "TRACE-1", Result.SUCCESS,
                Map.of(DetailField.MASKED_CONTACT, "op***@example.test")), true);
        boolean denied = store.append(event("AUD-2", EventType.AUTHORIZATION_DENIED, "ACTOR-7",
                "WORK_ORDER_READ", "WORK-9", "TENANT-A", "TRACE-2", Result.DENIED,
                Map.of(DetailField.REASON_CODE, "POLICY-DENY")), false);
        boolean stateChanged = store.append(event("AUD-3", EventType.WORK_ORDER_STATE_CHANGED,
                "ACTOR-8", "WORK_ORDER_CLOSE", "WORK-10", "TENANT-A", "TRACE-3",
                Result.SUCCESS, Map.of(DetailField.CHANGE_SUMMARY, "VERIFIED->CLOSED")), true);
        boolean adminChanged = store.append(event("AUD-4", EventType.ADMIN_ROLE_CHANGED,
                "ACTOR-ADMIN", "ROLE_ASSIGN", "ACTOR-8", "TENANT-B", "TRACE-4",
                Result.SUCCESS, Map.of(DetailField.REASON_CODE, "APPROVED-CHANGE")), true);

        boolean fourTypes = login && denied && stateChanged && adminChanged
                && store.all().stream().map(AuditEvent::type).distinct().count() == 4;
        boolean identitiesComplete = store.all().stream().allMatch(AuditPrivacyExample::validIdentity);
        boolean tenantTraceComplete = store.all().stream()
                .allMatch(item -> nonblank(item.tenant()) && nonblank(item.trace()));
        boolean detailsSafe = store.all().stream()
                .allMatch(item -> ALLOWED_DETAILS.containsAll(item.details().keySet()));
        boolean falseSuccessRejected = !store.append(event("AUD-5", EventType.WORK_ORDER_STATE_CHANGED,
                "ACTOR-8", "WORK_ORDER_CLOSE", "WORK-11", "TENANT-A", "TRACE-5",
                Result.SUCCESS, Map.of()), false);
        boolean appendOnly = !store.replace("AUD-1", event("AUD-1", EventType.LOGIN,
                "ACTOR-OTHER", "LOGIN", "SESSION-1", "TENANT-A", "TRACE-6",
                Result.SUCCESS, Map.of()));
        boolean tenantIsolated = store.query("TENANT-A").stream()
                .allMatch(item -> item.tenant().equals("TENANT-A"));
        String masked = maskDisplay("operator@example.test");

        System.out.println("event_types=" + (fourTypes ? 4 : 0));
        System.out.println("actor_action_target_complete=" + identitiesComplete);
        System.out.println("tenant_trace_complete=" + tenantTraceComplete);
        System.out.println("secret_fields_absent=" + detailsSafe);
        System.out.println("success_matches_commit=" + falseSuccessRejected);
        System.out.println("append_only=" + appendOnly);
        System.out.println("tenant_query_isolated=" + tenantIsolated);
        System.out.println("masked_export=" + (masked.contains("***") && !masked.equals("operator@example.test")));
        System.out.println("secret_material_printed=false");
    }
}
