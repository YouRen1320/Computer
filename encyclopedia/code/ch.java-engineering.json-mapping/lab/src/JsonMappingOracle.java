import java.math.BigDecimal;
import java.nio.file.Path;
import java.time.Instant;
import java.util.Objects;

public final class JsonMappingOracle {
    private static int assertions;

    private JsonMappingOracle() {
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
        if (args.length != 1) {
            throw new IllegalArgumentException("expected roundtrip path");
        }
        String base = """
                {"schemaVersion":1,"id":"WO-机泵-101","status":"CREATED",
                 "openedAt":"2026-07-16T01:30:00Z","amount":1234.50,"assignee":null}
                """;
        JsonSupport.WorkOrderJsonMapper.WorkOrder order = JsonSupport.WorkOrderJsonMapper.fromJson(
                base, JsonSupport.WorkOrderJsonMapper.UnknownFieldPolicy.REJECT);
        equal(1, order.schemaVersion(), "version");
        equal("WO-机泵-101", order.id(), "id");
        equal(JsonSupport.WorkOrderJsonMapper.Status.CREATED, order.status(), "status");
        equal(Instant.parse("2026-07-16T01:30:00Z"), order.openedAt(), "instant");
        check(order.amount().compareTo(new BigDecimal("1234.50")) == 0, "amount value");
        equal(2, order.amount().scale(), "amount scale");
        equal(JsonSupport.WorkOrderJsonMapper.Presence.EXPLICIT_NULL,
                order.assignee().presence(), "explicit null");
        String encoded = JsonSupport.WorkOrderJsonMapper.toJson(order);
        equal(order, JsonSupport.WorkOrderJsonMapper.fromJson(
                encoded, JsonSupport.WorkOrderJsonMapper.UnknownFieldPolicy.REJECT), "roundtrip");

        String missing = encoded.replace(",\"assignee\":null", "");
        JsonSupport.WorkOrderJsonMapper.WorkOrder missingOrder = JsonSupport.WorkOrderJsonMapper.fromJson(
                missing, JsonSupport.WorkOrderJsonMapper.UnknownFieldPolicy.REJECT);
        equal(JsonSupport.WorkOrderJsonMapper.Presence.MISSING,
                missingOrder.assignee().presence(), "missing presence");
        String withValue = encoded.replace("\"assignee\":null", "\"assignee\":\"tech-7\"");
        JsonSupport.WorkOrderJsonMapper.WorkOrder valueOrder = JsonSupport.WorkOrderJsonMapper.fromJson(
                withValue, JsonSupport.WorkOrderJsonMapper.UnknownFieldPolicy.REJECT);
        equal(JsonSupport.WorkOrderJsonMapper.Presence.VALUE,
                valueOrder.assignee().presence(), "value presence");
        equal("tech-7", valueOrder.assignee().value(), "value text");

        String unknown = missing.substring(0, missing.length() - 1) + ",\"priorityLabel\":\"P4\"}";
        String strictEvidence = "none";
        try {
            JsonSupport.WorkOrderJsonMapper.fromJson(
                    unknown, JsonSupport.WorkOrderJsonMapper.UnknownFieldPolicy.REJECT);
        } catch (JsonSupport.WorkOrderJsonMapper.MappingException expected) {
            strictEvidence = expected.getMessage();
        }
        equal("UNKNOWN_FIELD:priorityLabel", strictEvidence, "strict unknown");
        JsonSupport.WorkOrderJsonMapper.WorkOrder lenient = JsonSupport.WorkOrderJsonMapper.fromJson(
                unknown, JsonSupport.WorkOrderJsonMapper.UnknownFieldPolicy.IGNORE);
        equal("WO-机泵-101", lenient.id(), "lenient known data");

        check(rejects(base.replace("\"id\":\"WO-机泵-101\",", ""), "MISSING_FIELD:id"),
                "missing id");
        check(rejects(base.replace("\"status\":\"CREATED\"", "\"status\":null"), "NULL_REQUIRED:status"),
                "null status");
        check(rejects(base.replace("2026-07-16T01:30:00Z", "2026-07-16T09:30:00"),
                "INVALID_TIME:openedAt"), "invalid time");
        check(rejects(base.replace("1234.50", "-1.00"), "INVALID_AMOUNT:amount"),
                "negative amount");
        check(rejects(base.replace("1234.50", "1.234"), "INVALID_AMOUNT:amount"),
                "amount scale");
        check(rejects(base.replace("1234.50", "1e2"), "INVALID_AMOUNT:amount"),
                "positive exponent changes scale");
        check(rejects(base.replace("\"id\":\"WO-机泵-101\"",
                "\"id\":\"WO-机泵-101\",\"id\":\"WO-102\""), "DUPLICATE_FIELD:id"),
                "duplicate id");

        Path path = Path.of(args[0]);
        JsonSupport.JsonFiles.writeUtf8(path, encoded);
        String fileText = JsonSupport.JsonFiles.readUtf8(path);
        equal(encoded, fileText, "file text");
        equal(order, JsonSupport.WorkOrderJsonMapper.fromJson(
                fileText, JsonSupport.WorkOrderJsonMapper.UnknownFieldPolicy.REJECT), "file mapping");
        equal("quote:\" slash:\\", ((JsonSupport.FlatJson.TextValue) JsonSupport.FlatJson.parseObject(
                "{\"value\":\"quote:\\\" slash:\\\\\"}").get("value")).value(), "string escapes");
        check(rejects(base.replace("\"schemaVersion\":1", "\"schemaVersion\":2"),
                "UNSUPPORTED_VERSION:schemaVersion"), "future version");
        check(!JsonSupport.WorkOrderJsonMapper.toJson(missingOrder).contains("assignee"),
                "missing omitted on write");

        System.out.println("report.roundtrip=" + order.id() + "," + order.status() + ","
                + order.amount().toPlainString());
        System.out.println("report.presence=missing:" + missingOrder.assignee().presence()
                + ",null:" + order.assignee().presence() + ",value:" + valueOrder.assignee().presence());
        System.out.println("report.unknown=strict:" + strictEvidence + ",lenient:WO-101");
        System.out.println("report.file=utf8:" + fileText.contains("机泵"));
        System.out.println("report.errors=missing-id,null-status,invalid-time,negative-amount,scale,exponent,duplicate,version");
        System.out.println("assertions=" + assertions + " passed");
    }
}
