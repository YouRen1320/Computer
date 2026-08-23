public final class ToStringLeakFailure {
    private static final String CANARY = "SECRET-CANARY-C91D";

    private ToStringLeakFailure() {
    }

    static final class BrokenDeviceId {
        private final String value;
        private final String provisioningSecret;

        BrokenDeviceId(String value, String provisioningSecret) {
            this.value = value;
            this.provisioningSecret = provisioningSecret;
        }

        @Override
        public String toString() {
            return "BrokenDeviceId[value=" + value + ", provisioningSecret=" + provisioningSecret + "]";
        }
    }

    public static void main(String[] args) {
        String text = new BrokenDeviceId("DEV-001", CANARY).toString();
        if (text.contains(CANARY)) {
            System.err.println("TOSTRING_LEAK field=provisioningSecret canaryDetected=true");
            System.exit(5);
        }
        throw new AssertionError("fixture did not expose the canary");
    }
}
