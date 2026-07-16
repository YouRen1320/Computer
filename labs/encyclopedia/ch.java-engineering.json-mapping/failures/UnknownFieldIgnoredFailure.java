public final class UnknownFieldIgnoredFailure {
    private UnknownFieldIgnoredFailure() {
    }

    public static void main(String[] args) {
        String json = """
                {"schemaVersion":1,"id":"WO-101","status":"OPEN",
                 "openedAt":"2026-07-16T01:30:00Z","amount":10.00,"currency":"CNY"}
                """;
        JsonSupport.WorkOrderJsonMapper.WorkOrder order = JsonSupport.WorkOrderJsonMapper.fromJson(
                json, JsonSupport.WorkOrderJsonMapper.UnknownFieldPolicy.IGNORE);
        if (order.amount().toPlainString().equals("10.00")) {
            throw new IllegalStateException("UNKNOWN_FIELD_SILENTLY_IGNORED currency");
        }
    }
}
