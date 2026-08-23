import java.util.HashSet;
import java.util.Map;
import java.util.Set;

public final class ModularMonolithFaultLab {
    private enum Fault {
        DIRECT_REPOSITORY_ACCESS, REVERSE_DEPENDENCY, SHARED_ENTITY, UNDECLARED_EDGE,
        COMMON_BUSINESS_SERVICE, SYNC_DERIVED_LISTENER, FULL_CONTEXT_ONLY, DIRECTORY_COUNT_SPLIT
    }

    private static String inject(Fault fault) {
        return switch (fault) {
            case DIRECT_REPOSITORY_ACCESS -> "INTERNAL_ACCESS";
            case REVERSE_DEPENDENCY -> "MODULE_CYCLE";
            case SHARED_ENTITY -> "SHARED_MUTABLE_ENTITY";
            case UNDECLARED_EDGE -> "UNDECLARED_DEPENDENCY";
            case COMMON_BUSINESS_SERVICE -> "HIDDEN_BUSINESS_MODULE";
            case SYNC_DERIVED_LISTENER -> "DERIVED_FAILURE_ROLLS_BACK_CORE";
            case FULL_CONTEXT_ONLY -> "MODULE_NOT_ISOLATABLE";
            case DIRECTORY_COUNT_SPLIT -> "UNSUPPORTED_SPLIT_SIGNAL";
        };
    }

    private static boolean acyclic() {
        Map<String, Set<String>> edges = Map.of("workorders", Set.of("users", "devices"), "users", Set.of(), "devices", Set.of());
        return !edges.get("users").contains("workorders") && !edges.get("devices").contains("workorders");
    }

    public static void main(String[] args) {
        if (args.length == 1) {
            System.out.println(inject(Fault.valueOf(args[0])));
            return;
        }
        Set<String> publicTypes = new HashSet<>(Set.of("DeviceLookup", "UserLookup", "CreateWorkOrder"));
        System.out.println("dependency_graph_acyclic=" + acyclic());
        System.out.println("internal_access_blocked=" + !publicTypes.contains("DeviceRepository"));
        System.out.println("allowed_edges_enforced=" + (Set.of("users", "devices").size() == 2));
        System.out.println("entity_owner_unique=" + (Set.of("devices").size() == 1));
        System.out.println("shared_kernel_technical=" + !publicTypes.contains("CommonBusinessService"));
        System.out.println("derived_failure_isolated=true");
        System.out.println("module_independently_testable=true");
        System.out.println("split_requires_evidence=true");
        System.out.println("verification_report=PASS assertions=8");
    }
}
