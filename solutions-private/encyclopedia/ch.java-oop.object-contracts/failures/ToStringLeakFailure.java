public final class ToStringLeakFailure {
    private static final String CANARY = "PRIVATE-CANARY-22B7";

    private ToStringLeakFailure() {
    }

    record BrokenDeviceId(String value, String secret) {
    }

    public static void main(String[] args) {
        String text = new BrokenDeviceId("DEV-001", CANARY).toString();
        if (text.contains(CANARY)) {
            System.err.println("TOSTRING_LEAK field=secret canaryDetected=true");
            System.exit(5);
        }
        throw new AssertionError("fixture did not expose the canary");
    }
}
