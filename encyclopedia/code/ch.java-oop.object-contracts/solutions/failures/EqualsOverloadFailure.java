public final class EqualsOverloadFailure {
    private EqualsOverloadFailure() {
    }

    static final class BrokenDeviceId {
        private final String value;

        BrokenDeviceId(String value) {
            this.value = value;
        }

        boolean equals(BrokenDeviceId other) {
            return other != null && value.equals(other.value);
        }
    }

    public static void main(String[] args) {
        BrokenDeviceId first = new BrokenDeviceId("DEV-001");
        Object second = new BrokenDeviceId("DEV-001");
        if (first.equals((BrokenDeviceId) second) && !first.equals(second)) {
            System.err.println("EQUALS_OVERLOAD_BROKEN typedCall=true objectCall=false");
            System.exit(6);
        }
        throw new AssertionError("fixture did not expose overload dispatch");
    }
}
