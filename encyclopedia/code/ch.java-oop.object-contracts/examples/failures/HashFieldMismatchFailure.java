public final class HashFieldMismatchFailure {
    private HashFieldMismatchFailure() {
    }

    static final class BrokenDeviceId {
        private final String tenantId;
        private final String value;
        private final int revision;

        BrokenDeviceId(String tenantId, String value, int revision) {
            this.tenantId = tenantId;
            this.value = value;
            this.revision = revision;
        }

        @Override
        public boolean equals(Object other) {
            if (this == other) {
                return true;
            }
            if (!(other instanceof BrokenDeviceId that)) {
                return false;
            }
            return tenantId.equals(that.tenantId) && value.equals(that.value);
        }

        @Override
        public int hashCode() {
            int result = 31 * tenantId.hashCode() + value.hashCode();
            return 31 * result + revision;
        }
    }

    public static void main(String[] args) {
        BrokenDeviceId first = new BrokenDeviceId("TENANT-ALPHA", "DEV-001", 1);
        BrokenDeviceId second = new BrokenDeviceId("TENANT-ALPHA", "DEV-001", 2);
        boolean equal = first.equals(second);
        boolean hashesEqual = first.hashCode() == second.hashCode();
        if (equal && !hashesEqual) {
            System.err.println("HASH_CONTRACT_BROKEN equal=true hashesEqual=false");
            System.exit(4);
        }
        throw new AssertionError("fixture did not break the hash contract");
    }
}
