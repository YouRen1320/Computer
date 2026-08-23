public final class UnknownStatusFailure {
    enum WorkOrderStatus { CREATED, IN_PROGRESS, CANCELLED }

    public static void main(String[] args) {
        try {
            WorkOrderStatus.valueOf("CANCELED");
            throw new AssertionError("non-canonical spelling unexpectedly parsed");
        } catch (IllegalArgumentException expected) {
            System.err.println("LAB_UNKNOWN_STATUS input=CANCELED canonical=CANCELLED");
            System.exit(6);
        }
    }
}
