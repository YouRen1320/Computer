import java.util.ArrayList;
import java.util.EnumSet;
import java.util.LinkedHashMap;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.stream.Collectors;

/** A deterministic, offline example of traceable DFD -> threat -> control -> oracle links. */
public final class ThreatModelExample {
    enum NodeKind { EXTERNAL_ENTITY, PROCESS, DATA_STORE }
    enum Stride { S, T, R, I, D, E }

    record Node(String id, NodeKind kind, String trustZone) { }
    record Flow(String id, String source, String target, String dataClass,
                String trustLevel, String boundaryId) { }
    record Threat(String id, Stride stride, String flowId, String abuseCase, String actorId,
                  String controlId, String validationId) { }
    record Control(String id, String threatId) { }
    record Validation(String id, String threatId) { }
    record Model(List<Node> nodes, List<Flow> flows, Set<String> actors,
                 List<Threat> threats, List<Control> controls, List<Validation> validations) { }

    private ThreatModelExample() { }

    public static void main(String[] args) {
        Model model = factoryCareSlice();
        List<String> violations = validate(model);
        if (!violations.isEmpty()) {
            throw new IllegalStateException(String.join("\n", violations));
        }

        long crossings = model.flows().stream()
                .filter(flow -> !"NONE".equals(flow.boundaryId()))
                .count();
        String stride = EnumSet.allOf(Stride.class).stream()
                .filter(category -> model.threats().stream().anyMatch(t -> t.stride() == category))
                .map(Enum::name)
                .collect(Collectors.joining(","));
        long requiredAbuseCases = model.threats().stream()
                .map(Threat::abuseCase)
                .filter(Set.of("AUTH_BYPASS", "AUTHORIZATION_BYPASS", "TAMPERING", "DISCLOSURE")::contains)
                .distinct()
                .count();

        System.out.println("nodes=" + model.nodes().size());
        System.out.println("flows=" + model.flows().size());
        System.out.println("trust_crossings=" + crossings);
        System.out.println("stride_covered=" + stride);
        System.out.println("required_abuse_cases=" + requiredAbuseCases);
        System.out.println("control_links=" + model.controls().size());
        System.out.println("validation_links=" + model.validations().size());
        System.out.println("model_valid=true");
    }

    static Model factoryCareSlice() {
        List<Node> nodes = List.of(
                new Node("E_BROWSER", NodeKind.EXTERNAL_ENTITY, "UNTRUSTED_CLIENT"),
                new Node("P_PUBLIC_API", NodeKind.PROCESS, "APP"),
                new Node("P_WORK_ORDER", NodeKind.PROCESS, "APP"),
                new Node("D_POSTGRES", NodeKind.DATA_STORE, "DATA"),
                new Node("E_NOTIFICATION", NodeKind.EXTERNAL_ENTITY, "THIRD_PARTY")
        );
        List<Flow> flows = List.of(
                new Flow("F_CREATE_REQUEST", "E_BROWSER", "P_PUBLIC_API", "CONFIDENTIAL", "UNTRUSTED_INPUT", "TB_CLIENT_APP"),
                new Flow("F_VALIDATED_COMMAND", "P_PUBLIC_API", "P_WORK_ORDER", "INTERNAL", "VALIDATED_INTERNAL", "NONE"),
                new Flow("F_WORK_ORDER_WRITE", "P_WORK_ORDER", "D_POSTGRES", "CONFIDENTIAL", "PRIVILEGED_DATA", "TB_APP_DATA"),
                new Flow("F_NOTIFY", "P_WORK_ORDER", "E_NOTIFICATION", "MINIMIZED", "THIRD_PARTY_EGRESS", "TB_APP_VENDOR")
        );
        Set<String> actors = new LinkedHashSet<>(List.of(
                "ANONYMOUS", "LOW_PRIVILEGE_MEMBER", "ADMIN", "INSIDER", "COMPROMISED_VENDOR"));
        List<Threat> threats = List.of(
                new Threat("T_SPOOF", Stride.S, "F_CREATE_REQUEST", "AUTH_BYPASS", "ANONYMOUS", "C_AUTHN", "V_AUTHN"),
                new Threat("T_TAMPER", Stride.T, "F_CREATE_REQUEST", "TAMPERING", "LOW_PRIVILEGE_MEMBER", "C_INPUT_STATE", "V_TAMPER"),
                new Threat("T_REPUDIATE", Stride.R, "F_VALIDATED_COMMAND", "ADMIN_ABUSE", "ADMIN", "C_AUDIT", "V_AUDIT"),
                new Threat("T_DISCLOSE", Stride.I, "F_NOTIFY", "DISCLOSURE", "COMPROMISED_VENDOR", "C_MINIMIZE", "V_DISCLOSE"),
                new Threat("T_DOS", Stride.D, "F_CREATE_REQUEST", "RESOURCE_EXHAUSTION", "ANONYMOUS", "C_BOUNDS", "V_DOS"),
                new Threat("T_ELEVATE", Stride.E, "F_WORK_ORDER_WRITE", "AUTHORIZATION_BYPASS", "LOW_PRIVILEGE_MEMBER", "C_TENANT_SCOPE", "V_AUTHZ")
        );
        List<Control> controls = threats.stream()
                .map(threat -> new Control(threat.controlId(), threat.id()))
                .toList();
        List<Validation> validations = threats.stream()
                .map(threat -> new Validation(threat.validationId(), threat.id()))
                .toList();
        return new Model(nodes, flows, actors, threats, controls, validations);
    }

    static List<String> validate(Model model) {
        List<String> errors = new ArrayList<>();
        Map<String, Node> nodes = uniqueById(model.nodes(), Node::id, "NODE", errors);
        Map<String, Flow> flows = uniqueById(model.flows(), Flow::id, "FLOW", errors);
        Map<String, Threat> threats = uniqueById(model.threats(), Threat::id, "THREAT", errors);
        Map<String, Control> controls = uniqueById(model.controls(), Control::id, "CONTROL", errors);
        Map<String, Validation> validations = uniqueById(model.validations(), Validation::id, "VALIDATION", errors);

        for (Node node : model.nodes()) {
            if (node.trustZone() == null || node.trustZone().isBlank()) {
                errors.add("NODE_TRUST_MISSING:" + node.id());
            }
        }
        for (Flow flow : model.flows()) {
            Node source = nodes.get(flow.source());
            Node target = nodes.get(flow.target());
            if (source == null || target == null) {
                errors.add("FLOW_ENDPOINT_UNKNOWN:" + flow.id());
                continue;
            }
            if (flow.trustLevel() == null || flow.trustLevel().isBlank()) {
                errors.add("FLOW_TRUST_MISSING:" + flow.id());
            }
            boolean crosses = !source.trustZone().equals(target.trustZone());
            if (crosses && (flow.boundaryId() == null || "NONE".equals(flow.boundaryId()))) {
                errors.add("BOUNDARY_MISSING:" + flow.id());
            }
            if (!crosses && !"NONE".equals(flow.boundaryId())) {
                errors.add("BOUNDARY_FALSE_POSITIVE:" + flow.id());
            }
        }
        for (String actor : List.of("ADMIN", "INSIDER")) {
            if (!model.actors().contains(actor)) {
                errors.add("ACTOR_MISSING:" + actor);
            }
        }
        for (String abuse : List.of("AUTH_BYPASS", "AUTHORIZATION_BYPASS", "TAMPERING", "DISCLOSURE")) {
            if (model.threats().stream().noneMatch(threat -> abuse.equals(threat.abuseCase()))) {
                errors.add("ABUSE_CASE_MISSING:" + abuse);
            }
        }
        for (Threat threat : model.threats()) {
            if (!flows.containsKey(threat.flowId())) {
                errors.add("THREAT_FLOW_UNKNOWN:" + threat.id());
            }
            Control control = controls.get(threat.controlId());
            if (control == null || !threat.id().equals(control.threatId())) {
                errors.add("CONTROL_LINK_INVALID:" + threat.id());
            }
            Validation validation = validations.get(threat.validationId());
            if (validation == null || !threat.id().equals(validation.threatId())) {
                errors.add("VALIDATION_LINK_INVALID:" + threat.id());
            }
        }
        for (Control control : model.controls()) {
            Threat threat = threats.get(control.threatId());
            if (threat == null || !control.id().equals(threat.controlId())) {
                errors.add("ORPHAN_CONTROL:" + control.id());
            }
        }
        return List.copyOf(errors);
    }

    private static <T> Map<String, T> uniqueById(List<T> values,
                                                  java.util.function.Function<T, String> id,
                                                  String kind,
                                                  List<String> errors) {
        Map<String, T> result = new LinkedHashMap<>();
        for (T value : values) {
            String key = id.apply(value);
            if (result.putIfAbsent(key, value) != null) {
                errors.add(kind + "_DUPLICATE:" + key);
            }
        }
        return result;
    }
}
