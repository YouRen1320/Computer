public final class UnknownStatusFailure {
    enum Status { CREATED, CANCELLED }
    public static void main(String[] args) {
        try {
            Status.valueOf("CANCELED");
            throw new AssertionError("invalid spelling parsed");
        } catch (IllegalArgumentException expected) {
            System.err.println("SOLUTION_STATUS_REPLAY input=CANCELED canonical=CANCELLED");
            System.exit(9);
        }
    }
}
