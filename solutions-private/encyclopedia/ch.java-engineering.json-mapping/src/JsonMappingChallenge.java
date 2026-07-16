import java.math.BigDecimal;
import java.nio.file.Path;
import java.time.Instant;
import java.util.Objects;

public final class JsonMappingChallenge {
    private static int assertions;

    private JsonMappingChallenge() {
    }

    private static void check(boolean condition, String name) {
        assertions++;
        if (!condition) {
            throw new AssertionError(name);
        }
    }

    private static void equal(Object expected, Object actual, String name) {
        check(Objects.equals(expected, actual), name + " expected=" + expected + " actual=" + actual);
    }

    private static boolean rejects(String json, String evidence) {
        try {
            JsonSupport.WorkOrderJsonMapper.fromJson(
                    json, JsonSupport.WorkOrderJsonMapper.UnknownFieldPolicy.REJECT);
            return false;
        } catch (IllegalArgumentException expected) {
            return expected.getMessage().contains(evidence);
        }
    }

    public static void main(String[] args) throws Exception {
        String base = """
                {"schemaVersion":1,"id":"WO-机泵-101","status":"OPEN",
                 "openedAt":"2026-07-16T01:30:00Z","amount":10.50,"assignee":null}
                """;
        JsonSupport.WorkOrderJsonMapper.WorkOrder order = JsonSupport.WorkOrderJsonMapper.fromJson(
                base, JsonSupport.WorkOrderJsonMapper.UnknownFieldPolicy.REJECT);
        equal("WO-机泵-101", order.id(), "id");
        equal(JsonSupport.WorkOrderJsonMapper.Status.OPEN, order.status(), "status");
        equal(Instant.parse("2026-07-16T01:30:00Z"), order.openedAt(), "time");
        equal(new BigDecimal("10.50"), order.amount(), "amount");
        equal(2, order.amount().scale(), "scale");
        equal(JsonSupport.WorkOrderJsonMapper.Presence.EXPLICIT_NULL,
                order.assignee().presence(), "null presence");

        String missing = base.replace(",\"assignee\":null", "");
        String value = base.replace("\"assignee\":null", "\"assignee\":\"tech-7\"");
        equal(JsonSupport.WorkOrderJsonMapper.Presence.MISSING,
                JsonSupport.WorkOrderJsonMapper.fromJson(
                        missing, JsonSupport.WorkOrderJsonMapper.UnknownFieldPolicy.REJECT)
                        .assignee().presence(), "missing");
        JsonSupport.WorkOrderJsonMapper.OptionalText assigned = JsonSupport.WorkOrderJsonMapper.fromJson(
                value, JsonSupport.WorkOrderJsonMapper.UnknownFieldPolicy.REJECT).assignee();
        equal(JsonSupport.WorkOrderJsonMapper.Presence.VALUE, assigned.presence(), "value presence");
        equal("tech-7", assigned.value(), "value text");

        String unknown = base.replace("}", ",\"future\":\"x\"}");
        check(rejects(unknown, "UNKNOWN_FIELD:future"), "strict unknown");
        equal("WO-机泵-101", JsonSupport.WorkOrderJsonMapper.fromJson(
                unknown, JsonSupport.WorkOrderJsonMapper.UnknownFieldPolicy.IGNORE).id(), "lenient");
        check(rejects(base.replace("\"status\":\"OPEN\"", "\"status\":\"PAUSED\""),
                "INVALID_ENUM:status"), "enum");
        check(rejects(base.replace("10.50", "10.500"), "INVALID_AMOUNT:amount"), "scale failure");

        String encoded = JsonSupport.WorkOrderJsonMapper.toJson(order);
        equal(order, JsonSupport.WorkOrderJsonMapper.fromJson(
                encoded, JsonSupport.WorkOrderJsonMapper.UnknownFieldPolicy.REJECT), "roundtrip");
        Path path = Path.of(args[0]);
        JsonSupport.JsonFiles.writeUtf8(path, encoded);
        equal(encoded, JsonSupport.JsonFiles.readUtf8(path), "UTF-8 file");
        check(JsonSupport.JsonFiles.readUtf8(path).contains("机泵"), "Chinese retained");

        System.out.println("PRIVATE SOLUTION PASS assertions=" + assertions);
    }
}
