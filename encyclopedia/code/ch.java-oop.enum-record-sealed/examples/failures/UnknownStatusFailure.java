public final class UnknownStatusFailure {
    enum WorkOrderStatus { CREATED, IN_PROGRESS, CLOSED }

    public static void main(String[] args) {
        String raw = "IN_PROGRES";
        try {
            WorkOrderStatus.valueOf(raw);
            throw new AssertionError("misspelled status unexpectedly parsed");
        } catch (IllegalArgumentException expected) {
            System.err.println("STRING_STATUS_FAILURE input=IN_PROGRES exception=IllegalArgumentException");
            System.exit(4);
        }
    }
}
