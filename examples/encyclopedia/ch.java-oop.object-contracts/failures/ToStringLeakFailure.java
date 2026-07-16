public final class ToStringLeakFailure {
    private static final String CANARY = "TOKEN-CANARY-7F3A";

    private ToStringLeakFailure() {
    }

    record BrokenSnapshot(String deviceId, String accessToken) {
        @Override
        public String toString() {
            return "BrokenSnapshot[deviceId=" + deviceId + ", accessToken=" + accessToken + "]";
        }
    }

    public static void main(String[] args) {
        String text = new BrokenSnapshot("DEV-001", CANARY).toString();
        if (text.contains(CANARY)) {
            System.err.println("TOSTRING_LEAK field=accessToken canaryDetected=true");
            System.exit(5);
        }
        throw new AssertionError("fixture did not expose the canary");
    }
}
