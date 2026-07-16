public final class NullUnsafeEqualsFailure {
    private NullUnsafeEqualsFailure() {
    }

    static final class BrokenDeviceId {
        private final String value;

        BrokenDeviceId(String value) {
            this.value = value;
        }

        @Override
        public boolean equals(Object other) {
            BrokenDeviceId that = (BrokenDeviceId) other;
            return value.equals(that.value);
        }
    }

    public static void main(String[] args) {
        try {
            new BrokenDeviceId("DEV-001").equals(null);
            throw new AssertionError("fixture did not reject null unsafely");
        } catch (NullPointerException expected) {
            System.err.println("EQUALS_NULL_BROKEN exception=NullPointerException");
            System.exit(7);
        }
    }
}
