import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.EnumSet;
import java.util.LinkedHashMap;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;

/** Parses a tiny teaching schema and reports the first trustworthy structural violation. */
public final class ThreatModelLab {
    enum NodeKind { EXTERNAL_ENTITY, PROCESS, DATA_STORE }
    enum Stride { S, T, R, I, D, E }

    record Node(String id, NodeKind kind, String zone) { }
    record Flow(String id, String source, String target, String dataClass,
                String trustLevel, String boundary) { }
    record Threat(String id, Stride stride, String flow, String abuse, String actor,
                  String control, String validation) { }

    static final class Model {
        final Map<String, Node> nodes = new LinkedHashMap<>();
        final Map<String, Flow> flows = new LinkedHashMap<>();
        final Set<String> actors = new LinkedHashSet<>();
        final Map<String, Threat> threats = new LinkedHashMap<>();
        final Map<String, String> controls = new LinkedHashMap<>();
        final Map<String, String> validations = new LinkedHashMap<>();
    }

    private ThreatModelLab() { }

    public static void main(String[] args) throws IOException {
        if (args.length != 3) {
            throw new IllegalArgumentException("usage: ThreatModelLab MODEL FAULTS FAULT_ID");
        }
        Model model = parseModel(Path.of(args[0]));
        if (!"none".equals(args[2])) {
            applyFault(model, Path.of(args[1]), args[2]);
        }
        List<String> errors = validate(model);
        if (!errors.isEmpty()) {
            System.out.println("MODEL_INVALID first=" + errors.getFirst() + " total=" + errors.size());
            System.exit(1);
        }
        long crossings = model.flows.values().stream()
                .filter(flow -> !"NONE".equals(flow.boundary()))
                .count();
        System.out.printf("MODEL_VALID nodes=%d flows=%d threats=%d crossings=%d%n",
                model.nodes.size(), model.flows.size(), model.threats.size(), crossings);
    }

    static Model parseModel(Path path) throws IOException {
        Model model = new Model();
        for (String raw : Files.readAllLines(path)) {
            String line = raw.strip();
            if (line.isEmpty() || line.startsWith("#")) {
                continue;
            }
            String[] fields = line.split("\\|", -1);
            switch (fields[0]) {
                case "NODE" -> putUnique(model.nodes, fields[1],
                        new Node(fields[1], NodeKind.valueOf(fields[2]), fields[3]));
                case "FLOW" -> putUnique(model.flows, fields[1],
                        new Flow(fields[1], fields[2], fields[3], fields[4], fields[5], fields[6]));
                case "ACTOR" -> {
                    if (!model.actors.add(fields[1])) {
                        throw new IllegalArgumentException("DUPLICATE_ACTOR:" + fields[1]);
                    }
                }
                case "THREAT" -> putUnique(model.threats, fields[1],
                        new Threat(fields[1], Stride.valueOf(fields[2]), fields[3], fields[4],
                                fields[5], fields[6], fields[7]));
                case "CONTROL" -> putUnique(model.controls, fields[1], fields[2]);
                case "VALIDATION" -> putUnique(model.validations, fields[1], fields[2]);
                default -> throw new IllegalArgumentException("UNKNOWN_ROW:" + fields[0]);
            }
        }
        return model;
    }

    static void applyFault(Model model, Path faults, String wanted) throws IOException {
        for (String raw : Files.readAllLines(faults)) {
            String line = raw.strip();
            if (line.isEmpty() || line.startsWith("#")) {
                continue;
            }
            String[] fields = line.split("\\|", -1);
            if (!wanted.equals(fields[0])) {
                continue;
            }
            switch (fields[1]) {
                case "REMOVE_ACTOR" -> model.actors.remove(fields[2]);
                case "SET_BOUNDARY" -> {
                    Flow old = require(model.flows, fields[2]);
                    model.flows.put(old.id(), new Flow(old.id(), old.source(), old.target(),
                            old.dataClass(), old.trustLevel(), fields[3]));
                }
                case "ADD_CONTROL" -> model.controls.put(fields[2], fields[3]);
                case "REMOVE_VALIDATION" -> model.validations.remove(fields[2]);
                default -> throw new IllegalArgumentException("UNKNOWN_MUTATION:" + fields[1]);
            }
            return;
        }
        throw new IllegalArgumentException("UNKNOWN_FAULT:" + wanted);
    }

    static List<String> validate(Model model) {
        List<String> errors = new ArrayList<>();
        for (Node node : model.nodes.values()) {
            if (node.zone().isBlank()) {
                errors.add("NODE_TRUST_MISSING:" + node.id());
            }
        }
        for (Flow flow : model.flows.values()) {
            Node source = model.nodes.get(flow.source());
            Node target = model.nodes.get(flow.target());
            if (source == null || target == null) {
                errors.add("FLOW_ENDPOINT_UNKNOWN:" + flow.id());
                continue;
            }
            if (flow.dataClass().isBlank()) {
                errors.add("FLOW_DATA_CLASS_MISSING:" + flow.id());
            }
            if (flow.trustLevel().isBlank()) {
                errors.add("FLOW_TRUST_MISSING:" + flow.id());
            }
            boolean crosses = !source.zone().equals(target.zone());
            if (crosses && "NONE".equals(flow.boundary())) {
                errors.add("BOUNDARY_MISSING:" + flow.id());
            } else if (!crosses && !"NONE".equals(flow.boundary())) {
                errors.add("BOUNDARY_FALSE_POSITIVE:" + flow.id());
            }
        }
        for (String actor : List.of("ADMIN", "INSIDER")) {
            if (!model.actors.contains(actor)) {
                errors.add("ACTOR_MISSING:" + actor);
            }
        }
        for (String abuse : List.of("AUTH_BYPASS", "AUTHORIZATION_BYPASS", "TAMPERING", "DISCLOSURE")) {
            if (model.threats.values().stream().noneMatch(threat -> abuse.equals(threat.abuse()))) {
                errors.add("ABUSE_CASE_MISSING:" + abuse);
            }
        }
        EnumSet<Stride> covered = EnumSet.noneOf(Stride.class);
        for (Threat threat : model.threats.values()) {
            covered.add(threat.stride());
            if (!model.flows.containsKey(threat.flow())) {
                errors.add("THREAT_FLOW_UNKNOWN:" + threat.id());
            }
            if (!model.actors.contains(threat.actor())) {
                errors.add("THREAT_ACTOR_UNKNOWN:" + threat.id());
            }
            if (!threat.id().equals(model.controls.get(threat.control()))) {
                errors.add("CONTROL_LINK_INVALID:" + threat.id());
            }
            if (!threat.id().equals(model.validations.get(threat.validation()))) {
                errors.add("VALIDATION_LINK_INVALID:" + threat.id());
            }
        }
        for (Stride stride : Stride.values()) {
            if (!covered.contains(stride)) {
                errors.add("STRIDE_MISSING:" + stride);
            }
        }
        for (Map.Entry<String, String> control : model.controls.entrySet()) {
            Threat threat = model.threats.get(control.getValue());
            if (threat == null || !control.getKey().equals(threat.control())) {
                errors.add("ORPHAN_CONTROL:" + control.getKey());
            }
        }
        return List.copyOf(errors);
    }

    private static <T> void putUnique(Map<String, T> map, String id, T value) {
        if (map.putIfAbsent(id, value) != null) {
            throw new IllegalArgumentException("DUPLICATE_ID:" + id);
        }
    }

    private static <T> T require(Map<String, T> map, String id) {
        T value = map.get(id);
        if (value == null) {
            throw new IllegalArgumentException("UNKNOWN_ID:" + id);
        }
        return value;
    }
}
