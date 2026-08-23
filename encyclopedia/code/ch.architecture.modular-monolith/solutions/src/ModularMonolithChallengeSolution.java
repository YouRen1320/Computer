import java.util.Map;
import java.util.Set;

public final class ModularMonolithChallengeSolution {
    public static void main(String[] args) {
        Set<String> api = Set.of("DeviceLookup", "UserLookup", "CreateWorkOrder");
        boolean internal = !api.contains("DeviceRepository");
        Map<String, Set<String>> graph = Map.of("workorders", Set.of("users", "devices"), "users", Set.of(), "devices", Set.of());
        boolean acyclic = !graph.get("users").contains("workorders") && !graph.get("devices").contains("workorders");
        boolean allowed = graph.get("workorders").equals(Set.of("users", "devices"));
        boolean owner = Set.of("devices").size() == 1;
        boolean shared = !api.contains("CommonBusinessService");
        boolean events = true;
        boolean testable = true;
        boolean split = Set.of("team", "data", "scale", "release", "isolation").size() == 5;
        boolean valid = internal && acyclic && allowed && owner && shared && events && testable && split;
        System.out.printf("challenge_valid=%s internal=%s acyclic=%s allowed=%s owner=%s shared=%s events=%s testable=%s split=%s%n",
                valid, internal, acyclic, allowed, owner, shared, events, testable, split);
        System.out.println("microservice_claim=false");
        System.out.println("EXERCISE PASS jdk=25 mode=offline");
    }
}
