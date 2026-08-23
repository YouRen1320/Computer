public final class HashFieldMismatchFailure {
    private HashFieldMismatchFailure() {
    }

    record BrokenDeviceId(String tenantId, String value, int revision) {
        @Override
        public boolean equals(Object other) {
            return other instanceof BrokenDeviceId that
                    && tenantId.equals(that.tenantId)
                    && value.equals(that.value);
        }

        @Override
        public int hashCode() {
            return 31 * (31 * tenantId.hashCode() + value.hashCode()) + revision;
        }
    }

    public static void main(String[] args) {
        BrokenDeviceId first = new BrokenDeviceId("TENANT-ALPHA", "DEV-001", 1);
        BrokenDeviceId second = new BrokenDeviceId("TENANT-ALPHA", "DEV-001", 2);
        if (first.equals(second) && first.hashCode() != second.hashCode()) {
            System.err.println("HASH_CONTRACT_BROKEN equal=true hashesEqual=false");
            System.exit(4);
        }
        throw new AssertionError("fixture did not break the hash contract");
    }
}
