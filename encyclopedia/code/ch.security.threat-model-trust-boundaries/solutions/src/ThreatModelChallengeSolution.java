import java.util.List;
import java.util.Set;

/** Private oracle for the public trust-boundary and traceability challenge. */
public final class ThreatModelChallengeSolution {
    record Flow(String id, String sourceZone, String targetZone, String boundary) { }
    record Threat(String id, String abuseCase, String actor, String control, String validation) { }

    private ThreatModelChallengeSolution() { }

    public static void main(String[] args) {
        Flow crossing = new Flow("F_CREATE", "UNTRUSTED", "APP", "TB_CLIENT_APP");
        Flow missing = new Flow("F_BROKEN", "UNTRUSTED", "APP", "NONE");
        Flow internal = new Flow("F_INTERNAL", "APP", "APP", "NONE");
        require(hasValidBoundary(crossing), "VALID_CROSSING_REJECTED");
        require(!hasValidBoundary(missing), "MISSING_BOUNDARY_ACCEPTED");
        require(hasValidBoundary(internal), "INTERNAL_FLOW_REJECTED");

        Set<String> actors = Set.of("ANONYMOUS", "MEMBER", "ADMIN", "INSIDER");
        require(hasRequiredActors(actors), "REQUIRED_ACTOR_REJECTED");
        require(!hasRequiredActors(Set.of("ANONYMOUS", "MEMBER")), "MISSING_ADMIN_INSIDER_ACCEPTED");

        List<Threat> threats = List.of(
                new Threat("T1", "AUTH_BYPASS", "ANONYMOUS", "C1", "V1"),
                new Threat("T2", "AUTHORIZATION_BYPASS", "MEMBER", "C2", "V2"),
                new Threat("T3", "TAMPERING", "MEMBER", "C3", "V3"),
                new Threat("T4", "DISCLOSURE", "INSIDER", "C4", "V4"));
        require(threats.stream().allMatch(ThreatModelChallengeSolution::isMapped), "MAPPED_THREAT_REJECTED");
        require(!isMapped(new Threat("T5", "DISCLOSURE", "INSIDER", "", "V5")), "ORPHAN_THREAT_ACCEPTED");
        require(coversRequiredAbuseCases(threats), "ABUSE_COVERAGE_REJECTED");
        require(!coversRequiredAbuseCases(threats.subList(0, 3)), "MISSING_DISCLOSURE_ACCEPTED");

        System.out.println("challenge_valid=true trust_crossings=1 mapped_threats=4");
        System.out.println("EXERCISE PASS jdk=25 mode=offline");
    }

    static boolean hasValidBoundary(Flow flow) {
        boolean crosses = !flow.sourceZone().equals(flow.targetZone());
        return crosses ? !"NONE".equals(flow.boundary()) : "NONE".equals(flow.boundary());
    }

    static boolean hasRequiredActors(Set<String> actors) {
        return actors.contains("ADMIN") && actors.contains("INSIDER");
    }

    static boolean isMapped(Threat threat) {
        return !threat.control().isBlank() && !threat.validation().isBlank();
    }

    static boolean coversRequiredAbuseCases(List<Threat> threats) {
        Set<String> present = threats.stream().map(Threat::abuseCase).collect(java.util.stream.Collectors.toSet());
        return present.containsAll(Set.of("AUTH_BYPASS", "AUTHORIZATION_BYPASS", "TAMPERING", "DISCLOSURE"));
    }

    private static void require(boolean condition, String marker) {
        if (!condition) {
            throw new IllegalStateException(marker);
        }
    }
}
