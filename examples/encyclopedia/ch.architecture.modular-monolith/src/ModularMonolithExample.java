import java.util.ArrayDeque;
import java.util.HashMap;
import java.util.HashSet;
import java.util.Map;
import java.util.Set;
import java.util.TreeMap;
import java.util.TreeSet;

public final class ModularMonolithExample {
    private record Reference(String source, String target, boolean targetInternal) { }

    private static final class ModuleGraph {
        private final Map<String, Set<String>> allowed = new TreeMap<>();
        private final Set<Reference> references = new HashSet<>();

        void module(String name, String... dependencies) {
            allowed.put(name, new TreeSet<>(Set.of(dependencies)));
        }

        void reference(String source, String target, boolean targetInternal) {
            references.add(new Reference(source, target, targetInternal));
        }

        boolean internalsIsolated() {
            return references.stream().noneMatch(Reference::targetInternal);
        }

        boolean acyclic() {
            Map<String, Integer> indegree = new HashMap<>();
            allowed.keySet().forEach(module -> indegree.put(module, 0));
            allowed.forEach((source, targets) -> targets.forEach(target -> indegree.merge(target, 1, Integer::sum)));
            ArrayDeque<String> ready = new ArrayDeque<>();
            indegree.forEach((module, degree) -> { if (degree == 0) ready.add(module); });
            int visited = 0;
            while (!ready.isEmpty()) {
                String source = ready.remove();
                visited++;
                for (String target : allowed.getOrDefault(source, Set.of())) {
                    if (indegree.merge(target, -1, Integer::sum) == 0) ready.add(target);
                }
            }
            return visited == allowed.size();
        }
    }

    public static void main(String[] args) {
        ModuleGraph graph = new ModuleGraph();
        graph.module("devices");
        graph.module("reporting");
        graph.module("users");
        graph.module("workorders", "devices", "users");
        graph.reference("workorders", "devices", false);
        graph.reference("workorders", "users", false);
        System.out.println("modules=devices,reporting,users,workorders");
        System.out.println("deployment_units=1");
        System.out.println("allowed_edges=workorders->devices,workorders->users");
        System.out.println("acyclic=" + graph.acyclic());
        System.out.println("internal_isolated=" + graph.internalsIsolated());
        System.out.println("module_test_scope=workorders+direct-dependencies");
        System.out.println("event_producer_knows_consumers=false");
        System.out.println("split_decision=KEEP_MONOLITH");
        System.out.println("microservice_claim=false");
    }
}
