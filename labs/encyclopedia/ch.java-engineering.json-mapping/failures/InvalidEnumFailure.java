public final class InvalidEnumFailure {
    private InvalidEnumFailure() {
    }

    public static void main(String[] args) {
        String json = """
                {"schemaVersion":1,"id":"WO-101","status":"PAUSED",
                 "openedAt":"2026-07-16T01:30:00Z","amount":10.00}
                """;
        try {
            JsonSupport.WorkOrderJsonMapper.fromJson(
                    json, JsonSupport.WorkOrderJsonMapper.UnknownFieldPolicy.REJECT);
        } catch (JsonSupport.WorkOrderJsonMapper.MappingException expected) {
            throw new IllegalStateException("INVALID_ENUM:status", expected);
        }
        throw new AssertionError("INVALID_ENUM:status was not rejected");
    }
}
