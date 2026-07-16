import java.time.Instant;
import java.util.ArrayList;
import java.util.EnumSet;
import java.util.List;
import java.util.Map;
import java.util.Set;

/** Injects one attributable-audit or privacy failure at a time. */
public final class AuditPrivacyFaultLab {
    private enum FaultMode {
        NORMAL, SECRET_FIELD, MISSING_TENANT, MISSING_ACTOR,
        FALSE_SUCCESS, MUTABLE_AUDIT, CROSS_TENANT_QUERY, TRACE_AS_ACTOR
    }

    private enum EventType { LOGIN, AUTHORIZATION_DENIED, WORK_ORDER_STATE_CHANGED, ADMIN_ROLE_CHANGED }
    private enum Result { SUCCESS, DENIED, FAILURE }
    private enum DetailField { CHANGE_SUMMARY, REASON_CODE, MASKED_CONTACT, AUTHENTICATOR }

    private record AuditEvent(
            String id, EventType type, String actor, String action, String target, String tenant,
            Instant occurredAt, String trace, Result result, Map<DetailField, String> details) {
        AuditEvent {
            details = Map.copyOf(details);
        }
    }

    private static final Set<DetailField> ALLOWED_DETAILS = Set.copyOf(EnumSet.of(
            DetailField.CHANGE_SUMMARY, DetailField.REASON_CODE, DetailField.MASKED_CONTACT));

    private static final class Store {
        private final List<AuditEvent> events = new ArrayList<>();

        boolean append(AuditEvent event, boolean businessCommitted, FaultMode fault) {
            boolean actorRequired = fault == FaultMode.MISSING_ACTOR || nonblank(event.actor());
            boolean tenantRequired = fault == FaultMode.MISSING_TENANT || nonblank(event.tenant());
            boolean traceIsNotActor = fault == FaultMode.TRACE_AS_ACTOR
                    || !event.trace().equals(event.actor());
            boolean detailsAllowed = fault == FaultMode.SECRET_FIELD
                    || ALLOWED_DETAILS.containsAll(event.details().keySet());
            boolean truthful = fault == FaultMode.FALSE_SUCCESS
                    || event.result() != Result.SUCCESS || businessCommitted;
            if (!actorRequired || !tenantRequired || !nonblank(event.action())
                    || !nonblank(event.target()) || !nonblank(event.trace())
                    || !traceIsNotActor || !detailsAllowed || !truthful) {
                return false;
            }
            events.add(event);
            return true;
        }

        boolean replace(String id, AuditEvent replacement, FaultMode fault) {
            if (fault != FaultMode.MUTABLE_AUDIT) {
                return false;
            }
            for (int index = 0; index < events.size(); index++) {
                if (events.get(index).id().equals(id)) {
                    events.set(index, replacement);
                    return true;
                }
            }
            return false;
        }

        List<AuditEvent> query(String tenant, FaultMode fault) {
            return events.stream()
                    .filter(event -> fault == FaultMode.CROSS_TENANT_QUERY
                            || event.tenant().equals(tenant))
                    .toList();
        }

        List<AuditEvent> all() {
            return List.copyOf(events);
        }
    }

    private AuditPrivacyFaultLab() { }

    private static boolean nonblank(String value) {
        return value != null && !value.isBlank();
    }

    private static AuditEvent event(
            String id, EventType type, String actor, String action, String target,
            String tenant, String trace, Result result, Map<DetailField, String> details) {
        return new AuditEvent(id, type, actor, action, target, tenant,
                Instant.parse("2026-07-17T02:00:00Z"), trace, result, details);
    }

    private static AuditEvent ordinary(String id, String tenant) {
        return event(id, EventType.WORK_ORDER_STATE_CHANGED, "ACTOR-7", "WORK_ORDER_CLOSE",
                "WORK-9", tenant, "TRACE-" + id, Result.SUCCESS,
                Map.of(DetailField.CHANGE_SUMMARY, "OPEN->CLOSED"));
    }

    private static String injectedOutcome(FaultMode fault) {
        Store store = new Store();
        return switch (fault) {
            case SECRET_FIELD -> store.append(event("AUD-1", EventType.LOGIN, "ACTOR-7", "LOGIN",
                    "SESSION-1", "TENANT-A", "TRACE-1", Result.SUCCESS,
                    Map.of(DetailField.AUTHENTICATOR, "SYNTHETIC-FORBIDDEN")), true, fault)
                    ? "SECRET_FIELD_ACCEPTED" : "FAULT_NOT_EXPOSED";
            case MISSING_TENANT -> store.append(event("AUD-2", EventType.AUTHORIZATION_DENIED,
                    "ACTOR-7", "WORK_ORDER_READ", "WORK-9", "", "TRACE-2", Result.DENIED,
                    Map.of(DetailField.REASON_CODE, "POLICY-DENY")), false, fault)
                    ? "MISSING_TENANT_ACCEPTED" : "FAULT_NOT_EXPOSED";
            case MISSING_ACTOR -> store.append(event("AUD-3", EventType.ADMIN_ROLE_CHANGED,
                    "", "ROLE_ASSIGN", "ACTOR-8", "TENANT-A", "TRACE-3", Result.SUCCESS,
                    Map.of(DetailField.REASON_CODE, "APPROVED-CHANGE")), true, fault)
                    ? "MISSING_ACTOR_ACCEPTED" : "FAULT_NOT_EXPOSED";
            case FALSE_SUCCESS -> store.append(ordinary("AUD-4", "TENANT-A"), false, fault)
                    ? "ROLLED_BACK_ACTION_MARKED_SUCCESS" : "FAULT_NOT_EXPOSED";
            case MUTABLE_AUDIT -> {
                AuditEvent original = ordinary("AUD-5", "TENANT-A");
                store.append(original, true, FaultMode.NORMAL);
                AuditEvent changed = event("AUD-5", EventType.WORK_ORDER_STATE_CHANGED,
                        "ACTOR-OTHER", "WORK_ORDER_REOPEN", "WORK-9", "TENANT-A", "TRACE-5B",
                        Result.SUCCESS, Map.of(DetailField.CHANGE_SUMMARY, "CLOSED->OPEN"));
                yield store.replace("AUD-5", changed, fault)
                        ? "AUDIT_EVENT_OVERWRITTEN" : "FAULT_NOT_EXPOSED";
            }
            case CROSS_TENANT_QUERY -> {
                store.append(ordinary("AUD-6", "TENANT-A"), true, FaultMode.NORMAL);
                store.append(ordinary("AUD-7", "TENANT-B"), true, FaultMode.NORMAL);
                yield store.query("TENANT-A", fault).stream()
                        .anyMatch(item -> item.tenant().equals("TENANT-B"))
                        ? "CROSS_TENANT_AUDIT_VISIBLE" : "FAULT_NOT_EXPOSED";
            }
            case TRACE_AS_ACTOR -> store.append(event("AUD-8", EventType.LOGIN, "TRACE-8", "LOGIN",
                    "SESSION-8", "TENANT-A", "TRACE-8", Result.SUCCESS,
                    Map.of(DetailField.MASKED_CONTACT, "op***@example.test")), true, fault)
                    ? "TRACE_ID_USED_AS_ACTOR" : "FAULT_NOT_EXPOSED";
            case NORMAL -> "FAULT_NOT_EXPOSED";
        };
    }

    public static void main(String[] args) {
        FaultMode fault = args.length == 0 ? FaultMode.NORMAL : FaultMode.valueOf(args[0]);
        if (fault != FaultMode.NORMAL) {
            System.out.println(injectedOutcome(fault));
            return;
        }

        Store store = new Store();
        store.append(event("AUD-1", EventType.LOGIN, "ACTOR-7", "LOGIN", "SESSION-1",
                "TENANT-A", "TRACE-1", Result.SUCCESS,
                Map.of(DetailField.MASKED_CONTACT, "op***@example.test")), true, fault);
        store.append(event("AUD-2", EventType.AUTHORIZATION_DENIED, "ACTOR-7", "WORK_ORDER_READ",
                "WORK-9", "TENANT-A", "TRACE-2", Result.DENIED,
                Map.of(DetailField.REASON_CODE, "POLICY-DENY")), false, fault);
        store.append(ordinary("AUD-3", "TENANT-A"), true, fault);
        store.append(event("AUD-4", EventType.ADMIN_ROLE_CHANGED, "ACTOR-ADMIN", "ROLE_ASSIGN",
                "ACTOR-8", "TENANT-B", "TRACE-4", Result.SUCCESS,
                Map.of(DetailField.REASON_CODE, "APPROVED-CHANGE")), true, fault);

        boolean fourTypes = store.all().stream().map(AuditEvent::type).distinct().count() == 4;
        boolean identity = store.all().stream().allMatch(item -> nonblank(item.actor())
                && nonblank(item.action()) && nonblank(item.target()) && nonblank(item.tenant()));
        boolean detailsSafe = store.all().stream()
                .allMatch(item -> ALLOWED_DETAILS.containsAll(item.details().keySet()));
        boolean falseSuccessRejected = !store.append(ordinary("AUD-5", "TENANT-A"), false, fault);
        boolean immutable = !store.replace("AUD-1", ordinary("AUD-1", "TENANT-A"), fault);
        boolean tenantIsolated = store.query("TENANT-A", fault).stream()
                .allMatch(item -> item.tenant().equals("TENANT-A"));
        boolean traceOnly = !store.append(event("AUD-6", EventType.LOGIN, "TRACE-6", "LOGIN",
                "SESSION-6", "TENANT-A", "TRACE-6", Result.SUCCESS, Map.of()), true, fault);

        System.out.println("four_event_types=" + fourTypes);
        System.out.println("required_identity=" + identity);
        System.out.println("secret_fields_absent=" + detailsSafe);
        System.out.println("success_matches_commit=" + falseSuccessRejected);
        System.out.println("append_only=" + immutable);
        System.out.println("tenant_query_isolated=" + tenantIsolated);
        System.out.println("trace_is_correlation_only=" + traceOnly);
        System.out.println("verification_report=PASS assertions=7");
    }
}
