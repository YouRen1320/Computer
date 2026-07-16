public final class FieldDriftFailure {
    private FieldDriftFailure() {
    }

    public static void main(String[] args) {
        String json = """
                {"schemaVersion":1,"id":"WO-101","status":"OPEN",
                 "opened_at":"2026-07-16T01:30:00Z","amount":10.00}
                """;
        try {
            JsonSupport.WorkOrderJsonMapper.fromJson(
                    json, JsonSupport.WorkOrderJsonMapper.UnknownFieldPolicy.REJECT);
        } catch (JsonSupport.WorkOrderJsonMapper.MappingException expected) {
            throw new IllegalStateException("FIELD_DRIFT opened_at!=openedAt", expected);
        }
        throw new AssertionError("FIELD_DRIFT was not rejected");
    }
}
