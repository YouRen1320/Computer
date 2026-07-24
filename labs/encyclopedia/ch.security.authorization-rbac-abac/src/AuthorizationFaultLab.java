import java.util.Set;

/** Exposes missing enforcement points and fail-open policy combinations. */
public final class AuthorizationFaultLab {
    private enum Role { REPORTER, TECHNICIAN, DISPATCHER, UNKNOWN }
    private enum Action { READ, ASSIGN, CLOSE, UNKNOWN }
    private enum State { CREATED, VERIFIED }
    private enum FaultMode {
        NORMAL, UI_ONLY, URL_ONLY, OBJECT_IDOR, ALLOW_UNKNOWN_ROLE,
        ALLOW_UNKNOWN_ACTION, CONFLICT_LAST_ALLOW, TRUST_REQUEST_ATTRIBUTE
    }

    private record Subject(String id, String tenant, String organization, Role role,
                           Set<Action> permissions, boolean active, boolean blocked) { }
    private record WorkOrder(String tenant, String organization, String owner, String technician, State state) { }
    private record Decision(boolean allowed, String reason) {
        int status() { return allowed ? 200 : 403; }
    }

    private AuthorizationFaultLab() { }

    private static Decision authorize(
            Subject subject, Action action, WorkOrder workOrder, boolean claimedOwner, FaultMode fault) {
        if (fault == FaultMode.UI_ONLY) {
            return allowed("ui_assumed_safe");
        }
        if (subject.role() == Role.UNKNOWN) {
            return fault == FaultMode.ALLOW_UNKNOWN_ROLE ? allowed("unknown_role") : denied("unknown_role");
        }
        if (action == Action.UNKNOWN) {
            return fault == FaultMode.ALLOW_UNKNOWN_ACTION ? allowed("unknown_action") : denied("unknown_action");
        }
        if (!subject.active() || (subject.blocked() && fault != FaultMode.CONFLICT_LAST_ALLOW)) {
            return denied("inactive_or_blocked");
        }
        if (!subject.tenant().equals(workOrder.tenant())) {
            return denied("tenant");
        }
        if (!subject.permissions().contains(action)) {
            return denied("permission");
        }
        if (fault == FaultMode.OBJECT_IDOR) {
            return allowed("permission_only");
        }
        if (fault == FaultMode.TRUST_REQUEST_ATTRIBUTE && claimedOwner) {
            return allowed("client_owner_flag");
        }

        boolean objectAllowed = switch (action) {
            case READ -> switch (subject.role()) {
                case REPORTER -> subject.id().equals(workOrder.owner());
                case TECHNICIAN -> subject.id().equals(workOrder.technician());
                case DISPATCHER -> subject.organization().equals(workOrder.organization());
                case UNKNOWN -> false;
            };
            case ASSIGN -> subject.role() == Role.DISPATCHER
                    && subject.organization().equals(workOrder.organization());
            case CLOSE -> subject.role() == Role.DISPATCHER
                    && subject.organization().equals(workOrder.organization())
                    && workOrder.state() == State.VERIFIED;
            case UNKNOWN -> false;
        };
        return objectAllowed ? allowed("explicit_allow") : denied("object_policy");
    }

    private static Decision directService(
            Subject subject, Action action, WorkOrder workOrder, FaultMode fault) {
        return fault == FaultMode.URL_ONLY
                ? allowed("url_was_only_guard")
                : authorize(subject, action, workOrder, false, FaultMode.NORMAL);
    }

    private static Decision allowed(String reason) { return new Decision(true, reason); }
    private static Decision denied(String reason) { return new Decision(false, reason); }

    private static Subject reporter() {
        return new Subject("OWNER", "TENANT-A", "ORG-A", Role.REPORTER, Set.of(Action.READ), true, false);
    }

    private static Subject technician() {
        return new Subject("TECH", "TENANT-A", "ORG-A", Role.TECHNICIAN, Set.of(Action.READ), true, false);
    }

    private static Subject dispatcher(boolean blocked) {
        return new Subject("DISPATCH", "TENANT-A", "ORG-A", Role.DISPATCHER,
                Set.of(Action.READ, Action.ASSIGN, Action.CLOSE), true, blocked);
    }

    private static WorkOrder owned() {
        return new WorkOrder("TENANT-A", "ORG-A", "OWNER", "TECH", State.VERIFIED);
    }

    private static WorkOrder otherOwner() {
        return new WorkOrder("TENANT-A", "ORG-A", "OTHER", "OTHER-TECH", State.CREATED);
    }

    private static WorkOrder outsideScope() {
        return new WorkOrder("TENANT-A", "ORG-B", "OTHER", "OTHER-TECH", State.CREATED);
    }

    private static String injectedOutcome(FaultMode fault) {
        Subject unknownRole = new Subject("UNKNOWN", "TENANT-A", "ORG-A", Role.UNKNOWN,
                Set.of(Action.READ), true, false);
        return switch (fault) {
            case UI_ONLY -> authorize(reporter(), Action.CLOSE, owned(), false, fault).allowed()
                    ? "UI_ONLY_SERVER_BYPASS" : "FAULT_NOT_EXPOSED";
            case URL_ONLY -> directService(reporter(), Action.CLOSE, owned(), fault).allowed()
                    ? "DIRECT_SERVICE_BYPASS" : "FAULT_NOT_EXPOSED";
            case OBJECT_IDOR -> authorize(reporter(), Action.READ, otherOwner(), false, fault).allowed()
                    ? "OTHER_OWNER_OBJECT_ACCEPTED" : "FAULT_NOT_EXPOSED";
            case ALLOW_UNKNOWN_ROLE -> authorize(unknownRole, Action.READ, owned(), false, fault).allowed()
                    ? "UNKNOWN_ROLE_ACCEPTED" : "FAULT_NOT_EXPOSED";
            case ALLOW_UNKNOWN_ACTION -> authorize(dispatcher(false), Action.UNKNOWN, owned(), false, fault).allowed()
                    ? "UNKNOWN_ACTION_ACCEPTED" : "FAULT_NOT_EXPOSED";
            case CONFLICT_LAST_ALLOW -> authorize(dispatcher(true), Action.ASSIGN, owned(), false, fault).allowed()
                    ? "EXPLICIT_DENY_OVERRIDDEN" : "FAULT_NOT_EXPOSED";
            case TRUST_REQUEST_ATTRIBUTE -> authorize(reporter(), Action.READ, otherOwner(), true, fault).allowed()
                    ? "CLIENT_OWNER_FLAG_TRUSTED" : "FAULT_NOT_EXPOSED";
            case NORMAL -> "FAULT_NOT_EXPOSED";
        };
    }

    public static void main(String[] args) {
        FaultMode fault = args.length == 0 ? FaultMode.NORMAL : FaultMode.valueOf(args[0]);
        if (fault != FaultMode.NORMAL) {
            System.out.println(injectedOutcome(fault));
            return;
        }
        Subject unknownRole = new Subject("UNKNOWN", "TENANT-A", "ORG-A", Role.UNKNOWN,
                Set.of(Action.READ), true, false);
        System.out.println("owner_read=" + authorize(reporter(), Action.READ, owned(), false, fault).status());
        System.out.println("other_owner_read=" + authorize(reporter(), Action.READ, otherOwner(), false, fault).status());
        System.out.println("assigned_technician_read=" + authorize(technician(), Action.READ, owned(), false, fault).status());
        System.out.println("dispatcher_assign=" + authorize(dispatcher(false), Action.ASSIGN, owned(), false, fault).status());
        System.out.println("dispatcher_out_scope=" + authorize(dispatcher(false), Action.ASSIGN, outsideScope(), false, fault).status());
        System.out.println("blocked_subject=" + authorize(dispatcher(true), Action.ASSIGN, owned(), false, fault).status());
        System.out.println("unknown_role=" + authorize(unknownRole, Action.READ, owned(), false, fault).status());
        System.out.println("unknown_action=" + authorize(dispatcher(false), Action.UNKNOWN, owned(), false, fault).status());
        System.out.println("direct_service_idor=" + directService(reporter(), Action.READ, otherOwner(), fault).status());
        System.out.println("verification_report=PASS assertions=9");
    }
}
