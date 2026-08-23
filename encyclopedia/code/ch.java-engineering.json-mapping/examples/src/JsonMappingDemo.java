import java.math.BigDecimal;
import java.nio.file.Path;
import java.time.Instant;

public final class JsonMappingDemo {
    private JsonMappingDemo() {
    }

    public static void main(String[] args) throws Exception {
        if (args.length != 1) {
            throw new IllegalArgumentException("expected output path");
        }
        JsonSupport.WorkOrderJsonMapper.WorkOrder order = new JsonSupport.WorkOrderJsonMapper.WorkOrder(
                1,
                "WO-机泵-101",
                JsonSupport.WorkOrderJsonMapper.Status.CREATED,
                Instant.parse("2026-07-16T01:30:00Z"),
                new BigDecimal("1234.50"),
                JsonSupport.WorkOrderJsonMapper.OptionalText.explicitNull());
        String json = JsonSupport.WorkOrderJsonMapper.toJson(order);
        Path path = Path.of(args[0]);
        JsonSupport.JsonFiles.writeUtf8(path, json);
        String read = JsonSupport.JsonFiles.readUtf8(path);
        JsonSupport.WorkOrderJsonMapper.WorkOrder roundTrip = JsonSupport.WorkOrderJsonMapper.fromJson(
                read, JsonSupport.WorkOrderJsonMapper.UnknownFieldPolicy.REJECT);

        String withUnknown = json.substring(0, json.length() - 1) + ",\"priorityLabel\":\"P4\"}";
        JsonSupport.WorkOrderJsonMapper.WorkOrder lenient = JsonSupport.WorkOrderJsonMapper.fromJson(
                withUnknown, JsonSupport.WorkOrderJsonMapper.UnknownFieldPolicy.IGNORE);
        String strictEvidence = "none";
        try {
            JsonSupport.WorkOrderJsonMapper.fromJson(
                    withUnknown, JsonSupport.WorkOrderJsonMapper.UnknownFieldPolicy.REJECT);
        } catch (JsonSupport.WorkOrderJsonMapper.MappingException expected) {
            strictEvidence = expected.getMessage();
        }

        System.out.println("json=" + json);
        System.out.println("roundtrip.equal=" + order.equals(roundTrip));
        System.out.println("assignee.presence=" + roundTrip.assignee().presence());
        System.out.println("unknown.lenient.id=" + lenient.id());
        System.out.println("strict.unknown=" + strictEvidence);
        System.out.println("time.instant=" + roundTrip.openedAt());
        System.out.println("amount.plain=" + roundTrip.amount().toPlainString());
        System.out.println("file.utf8=" + read.contains("机泵"));
    }
}
