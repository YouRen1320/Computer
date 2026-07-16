import java.util.Set;

/** Private reference for closed-world RBAC/ABAC decisions. */
public final class AuthorizationPolicyChallengeSolution {
    enum Role { REPORTER, TECHNICIAN, DISPATCHER, UNKNOWN }
    enum Action { READ, ASSIGN, CLOSE, UNKNOWN }
    record Subject(String id, String tenant, String organization, Role role, Set<Action> permissions) { }
    record WorkOrder(String tenant, String organization, String owner, String technician) { }

    private AuthorizationPolicyChallengeSolution() { }

    public static void main(String[] args) {
        Subject owner = new Subject("OWNER", "TENANT-A", "ORG-A", Role.REPORTER, Set.of(Action.READ));
        Subject technician = new Subject("TECH", "TENANT-A", "ORG-A", Role.TECHNICIAN, Set.of(Action.READ));
        Subject dispatcher = new Subject("DISPATCH", "TENANT-A", "ORG-A", Role.DISPATCHER,
                Set.of(Action.READ, Action.ASSIGN, Action.CLOSE));
        WorkOrder owned = new WorkOrder("TENANT-A", "ORG-A", "OWNER", "TECH");
        WorkOrder other = new WorkOrder("TENANT-A", "ORG-A", "OTHER", "OTHER-TECH");

        require(knownRole(Role.REPORTER), "KNOWN_ROLE_REJECTED");
        require(!knownRole(Role.UNKNOWN), "UNKNOWN_ROLE_ALLOWED");
        require(knownAction(Action.READ), "KNOWN_ACTION_REJECTED");
        require(!knownAction(Action.UNKNOWN), "UNKNOWN_ACTION_ALLOWED");
        require(hasPermission(dispatcher.permissions(), Action.ASSIGN), "PERMISSION_REJECTED");
        require(!hasPermission(owner.permissions(), Action.CLOSE), "MISSING_PERMISSION_ALLOWED");
        require(sameTenant(owner, owned), "SAME_TENANT_REJECTED");
        require(!sameTenant(owner, new WorkOrder("TENANT-B", "ORG-A", "OWNER", "TECH")),
                "CROSS_TENANT_ALLOWED");
        require(objectRelation(owner, owned, Action.READ), "OWNER_READ_REJECTED");
        require(!objectRelation(owner, other, Action.READ), "OTHER_OWNER_OBJECT_ACCEPTED");
        require(objectRelation(technician, owned, Action.READ), "ASSIGNED_TECHNICIAN_REJECTED");
        require(objectRelation(dispatcher, owned, Action.ASSIGN), "IN_SCOPE_DISPATCH_REJECTED");
        require(!combineDecision(true, true), "EXPLICIT_DENY_OVERRIDDEN");
        require(combineDecision(false, true), "EXPLICIT_ALLOW_REJECTED");
        require(serviceGuard(true, true, true), "VALID_SERVICE_CALL_REJECTED");
        require(!serviceGuard(true, false, true), "DIRECT_SERVICE_BYPASS");
        require(!serviceGuard(true, true, false), "OBJECT_POLICY_BYPASS");

        System.out.println("challenge_valid=true role=true action=true permission=true tenant=true object=true conflict=true service=true");
        System.out.println("EXERCISE PASS jdk=25 mode=offline");
    }

    static boolean knownRole(Role role) {
        return role != null && role != Role.UNKNOWN;
    }

    static boolean knownAction(Action action) {
        return action != null && action != Action.UNKNOWN;
    }

    static boolean hasPermission(Set<Action> permissions, Action action) {
        return knownAction(action) && permissions.contains(action);
    }

    static boolean sameTenant(Subject subject, WorkOrder workOrder) {
        return subject.tenant().equals(workOrder.tenant());
    }

    static boolean objectRelation(Subject subject, WorkOrder workOrder, Action action) {
        return switch (action) {
            case READ -> switch (subject.role()) {
                case REPORTER -> subject.id().equals(workOrder.owner());
                case TECHNICIAN -> subject.id().equals(workOrder.technician());
                case DISPATCHER -> subject.organization().equals(workOrder.organization());
                case UNKNOWN -> false;
            };
            case ASSIGN, CLOSE -> subject.role() == Role.DISPATCHER
                    && subject.organization().equals(workOrder.organization());
            case UNKNOWN -> false;
        };
    }

    static boolean combineDecision(boolean explicitDeny, boolean permissionAndObjectAllow) {
        return !explicitDeny && permissionAndObjectAllow;
    }

    static boolean serviceGuard(boolean requestAllowed, boolean methodAllowed, boolean objectAllowed) {
        return requestAllowed && methodAllowed && objectAllowed;
    }

    private static void require(boolean condition, String marker) {
        if (!condition) {
            throw new IllegalStateException(marker);
        }
    }
}
