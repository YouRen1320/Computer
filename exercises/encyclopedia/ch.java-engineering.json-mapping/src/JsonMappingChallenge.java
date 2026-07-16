import java.nio.file.Path;

public final class JsonMappingChallenge {
    private JsonMappingChallenge() {
    }

    public static void main(String[] args) throws Exception {
        String base = """
                {"schemaVersion":1,"id":"WO-机泵-101","status":"OPEN",
                 "openedAt":"2026-07-16T01:30:00Z","amount":10.50,"assignee":null}
                """;
        JsonSupport.WorkOrderJsonMapper.WorkOrder order = JsonSupport.WorkOrderJsonMapper.fromJson(
                base, JsonSupport.WorkOrderJsonMapper.UnknownFieldPolicy.REJECT);
        String encoded = JsonSupport.WorkOrderJsonMapper.toJson(order);
        String missing = base.replace(",\"assignee\":null", "");
        String value = base.replace("\"assignee\":null", "\"assignee\":\"tech-7\"");
        boolean strictUnknown = false;
        try {
            JsonSupport.WorkOrderJsonMapper.fromJson(
                    base.replace("}", ",\"future\":\"x\"}"),
                    JsonSupport.WorkOrderJsonMapper.UnknownFieldPolicy.REJECT);
        } catch (JsonSupport.WorkOrderJsonMapper.MappingException expected) {
            strictUnknown = expected.getMessage().contains("UNKNOWN_FIELD:future");
        }
        Path path = Path.of(args[0]);
        JsonSupport.JsonFiles.writeUtf8(path, encoded);
        boolean valid = order.id().equals("WO-机泵-101")
                && order.assignee().presence() == JsonSupport.WorkOrderJsonMapper.Presence.EXPLICIT_NULL
                && JsonSupport.WorkOrderJsonMapper.fromJson(
                        missing, JsonSupport.WorkOrderJsonMapper.UnknownFieldPolicy.REJECT)
                        .assignee().presence() == JsonSupport.WorkOrderJsonMapper.Presence.MISSING
                && JsonSupport.WorkOrderJsonMapper.fromJson(
                        value, JsonSupport.WorkOrderJsonMapper.UnknownFieldPolicy.REJECT)
                        .assignee().presence() == JsonSupport.WorkOrderJsonMapper.Presence.VALUE
                && strictUnknown
                && JsonSupport.WorkOrderJsonMapper.fromJson(
                        JsonSupport.JsonFiles.readUtf8(path),
                        JsonSupport.WorkOrderJsonMapper.UnknownFieldPolicy.REJECT).equals(order);
        if (!valid) {
            throw new IllegalStateException("JSON_MAPPING_CONTRACT complete TODO 1..5");
        }
        System.out.println("CHALLENGE PASS assertions=6");
    }
}
