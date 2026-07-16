public final class SymmetryFailure {
    private SymmetryFailure() {
    }

    static class BaseDeviceId {
        final String value;

        BaseDeviceId(String value) {
            this.value = value;
        }

        @Override
        public boolean equals(Object other) {
            return other instanceof BaseDeviceId that && value.equals(that.value);
        }

        @Override
        public int hashCode() {
            return value.hashCode();
        }
    }

    static final class TenantDeviceId extends BaseDeviceId {
        private final String tenantId;

        TenantDeviceId(String tenantId, String value) {
            super(value);
            this.tenantId = tenantId;
        }

        @Override
        public boolean equals(Object other) {
            return other instanceof TenantDeviceId that
                    && super.equals(that)
                    && tenantId.equals(that.tenantId);
        }

        @Override
        public int hashCode() {
            return 31 * super.hashCode() + tenantId.hashCode();
        }
    }

    public static void main(String[] args) {
        BaseDeviceId base = new BaseDeviceId("DEV-001");
        BaseDeviceId scoped = new TenantDeviceId("TENANT-ALPHA", "DEV-001");
        boolean forward = base.equals(scoped);
        boolean reverse = scoped.equals(base);
        if (forward && !reverse) {
            System.err.println("EQUALS_SYMMETRY_BROKEN baseToChild=true childToBase=false");
            System.exit(6);
        }
        throw new AssertionError("fixture did not break symmetry");
    }
}
