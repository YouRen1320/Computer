import java.util.Set;

/** Combines RBAC candidates with object-level ABAC and closed-world defaults. */
public final class AuthorizationPolicyExample {
    private enum Role { REPORTER, TECHNICIAN, DISPATCHER, TENANT_ADMIN, UNKNOWN }
    private enum Action { READ, ASSIGN, CLOSE, UNKNOWN }
    private enum State { OPEN, VERIFIED, CLOSED }

    private record Subject(
            String membershipId,
            String tenantId,
            String organizationId,
            Role role,
            Set<Action> permissions,
            boolean active) { }

    private record WorkOrder(
            String tenantId,
            String organizationId,
            String ownerMembershipId,
            String assignedTechnicianId,
            State state) { }

    private record Decision(boolean allowed, String category) {
        int status() {
            return allowed ? 200 : 403;
        }
    }

    private AuthorizationPolicyExample() { }

    private static Decision authorize(Subject subject, Action action, WorkOrder workOrder) {
        if (!subject.active() || subject.role() == Role.UNKNOWN || action == Action.UNKNOWN) {
            return denied("unknown_or_inactive");
        }
        if (!subject.tenantId().equals(workOrder.tenantId())) {
            return denied("tenant");
        }
        if (!subject.permissions().contains(action)) {
            return denied("permission");
        }

        boolean allowed = switch (action) {
            case READ -> switch (subject.role()) {
                case REPORTER -> subject.membershipId().equals(workOrder.ownerMembershipId());
                case TECHNICIAN -> subject.membershipId().equals(workOrder.assignedTechnicianId());
                case DISPATCHER, TENANT_ADMIN -> subject.organizationId().equals(workOrder.organizationId());
                case UNKNOWN -> false;
            };
            case ASSIGN -> subject.role() == Role.DISPATCHER
                    && subject.organizationId().equals(workOrder.organizationId())
                    && workOrder.state() != State.CLOSED;
            case CLOSE -> subject.role() == Role.DISPATCHER
                    && subject.organizationId().equals(workOrder.organizationId())
                    && workOrder.state() == State.VERIFIED;
            case UNKNOWN -> false;
        };
        return allowed ? new Decision(true, "explicit_allow") : denied("object_policy");
    }

    private static Decision denied(String category) {
        return new Decision(false, category);
    }

    private static int directServiceCall(Subject subject, Action action, WorkOrder workOrder) {
        return authorize(subject, action, workOrder).status();
    }

    public static void main(String[] args) {
        Subject owner = new Subject("MEMBER-OWNER", "TENANT-A", "ORG-A", Role.REPORTER,
                Set.of(Action.READ), true);
        Subject technician = new Subject("MEMBER-TECH", "TENANT-A", "ORG-A", Role.TECHNICIAN,
                Set.of(Action.READ), true);
        Subject dispatcher = new Subject("MEMBER-DISPATCH", "TENANT-A", "ORG-A", Role.DISPATCHER,
                Set.of(Action.READ, Action.ASSIGN, Action.CLOSE), true);
        Subject unknown = new Subject("MEMBER-UNKNOWN", "TENANT-A", "ORG-A", Role.UNKNOWN,
                Set.of(Action.READ), true);
        WorkOrder owned = new WorkOrder("TENANT-A", "ORG-A", "MEMBER-OWNER", "MEMBER-TECH", State.VERIFIED);
        WorkOrder anotherOwner = new WorkOrder("TENANT-A", "ORG-A", "MEMBER-OTHER", "MEMBER-OTHER-TECH", State.OPEN);
        WorkOrder outsideScope = new WorkOrder("TENANT-A", "ORG-B", "MEMBER-OTHER", "MEMBER-OTHER-TECH", State.OPEN);

        System.out.println("owner_read=" + authorize(owner, Action.READ, owned).status());
        System.out.println("other_owner_read=" + authorize(owner, Action.READ, anotherOwner).status());
        System.out.println("assigned_technician_read=" + authorize(technician, Action.READ, owned).status());
        System.out.println("unassigned_technician_read=" + authorize(technician, Action.READ, anotherOwner).status());
        System.out.println("dispatcher_assign_in_scope=" + authorize(dispatcher, Action.ASSIGN, owned).status());
        System.out.println("dispatcher_assign_out_scope=" + authorize(dispatcher, Action.ASSIGN, outsideScope).status());
        System.out.println("dispatcher_close_verified=" + authorize(dispatcher, Action.CLOSE, owned).status());
        System.out.println("unknown_role=" + authorize(unknown, Action.READ, owned).status());
        System.out.println("unknown_action=" + authorize(dispatcher, Action.UNKNOWN, owned).status());
        System.out.println("direct_service_idor=" + directServiceCall(owner, Action.READ, anotherOwner));
        System.out.println("default_deny=" + !authorize(unknown, Action.UNKNOWN, outsideScope).allowed());
    }
}
