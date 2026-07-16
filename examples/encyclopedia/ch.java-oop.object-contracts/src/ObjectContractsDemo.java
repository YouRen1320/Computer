public final class ObjectContractsDemo {
    private ObjectContractsDemo() {
    }

    /** 不可变值对象：相等与哈希使用完全相同的两个组成字段。 */
    static final class DeviceId {
        private final String tenantId;
        private final String value;

        DeviceId(String tenantId, String value) {
            this.tenantId = normalizeTenant(tenantId);
            this.value = normalizeValue(value);
        }

        @Override
        public boolean equals(Object other) {
            if (this == other) {
                return true;
            }
            if (other == null || getClass() != other.getClass()) {
                return false;
            }
            DeviceId that = (DeviceId) other;
            return tenantId.equals(that.tenantId) && value.equals(that.value);
        }

        @Override
        public int hashCode() {
            int result = tenantId.hashCode();
            return 31 * result + value.hashCode();
        }

        @Override
        public String toString() {
            return "DeviceId[tenant=<redacted>, value=" + value + "]";
        }

        private static String normalizeTenant(String tenantId) {
            if (tenantId == null || tenantId.isBlank()) {
                throw new IllegalArgumentException("tenantId must have text");
            }
            return tenantId.trim().toUpperCase();
        }

        private static String normalizeValue(String value) {
            if (value == null || value.isBlank()) {
                throw new IllegalArgumentException("value must have text");
            }
            return value.trim().toUpperCase();
        }
    }

    public static void main(String[] args) {
        int assertions = 0;
        DeviceId first = new DeviceId("TENANT-ALPHA", "DEV-001");
        DeviceId second = new DeviceId("TENANT-ALPHA", "DEV-001");
        DeviceId third = new DeviceId(" TENANT-ALPHA ", " dev-001 ");
        DeviceId otherTenant = new DeviceId("TENANT-BETA", "DEV-001");
        DeviceId otherValue = new DeviceId("TENANT-ALPHA", "DEV-002");

        assertions = check(first != second, "separate identities", assertions);
        assertions = check(first.equals(first), "reflexive", assertions);
        assertions = check(first.equals(second), "same value", assertions);
        assertions = check(second.equals(first), "symmetric", assertions);
        assertions = check(first.equals(second) && second.equals(third) && first.equals(third),
                "transitive", assertions);
        assertions = check(first.equals(second), "consistent first read", assertions);
        assertions = check(first.equals(second), "consistent second read", assertions);
        assertions = check(!first.equals(null), "null false", assertions);
        assertions = check(!first.equals("TENANT-ALPHA/DEV-001"), "different type false", assertions);
        assertions = check(!first.equals(otherTenant), "tenant participates", assertions);
        assertions = check(!first.equals(otherValue), "value participates", assertions);
        assertions = check(first.hashCode() == second.hashCode(), "equal hash", assertions);
        assertions = check(second.hashCode() == third.hashCode(), "normalized equal hash", assertions);

        String text = first.toString();
        assertions = check("DeviceId[tenant=<redacted>, value=DEV-001]".equals(text),
                "stable diagnostic shape", assertions);
        assertions = check(!text.contains("TENANT-ALPHA"), "tenant redacted", assertions);
        assertions = check(text.contains("DEV-001"), "safe identifier visible", assertions);
        assertions = expectInvalidTenant(assertions);
        assertions = expectInvalidValue(assertions);

        System.out.println("identity=" + (first == second));
        System.out.println("valueEqual=" + first.equals(second));
        System.out.println("symmetric=" + (first.equals(second) && second.equals(first)));
        System.out.println("transitive=" + (first.equals(second) && second.equals(third) && first.equals(third)));
        System.out.println("equalHash=" + (first.hashCode() == second.hashCode()));
        System.out.println("otherTenantEqual=" + first.equals(otherTenant));
        System.out.println("text=" + text);
        System.out.println("protectedVisible=" + text.contains("TENANT-ALPHA"));
        System.out.println("assertions=" + assertions + " passed");
    }

    private static int expectInvalidTenant(int assertions) {
        try {
            new DeviceId(" ", "DEV-001");
            throw new AssertionError("blank tenant must fail");
        } catch (IllegalArgumentException expected) {
            return assertions + 1;
        }
    }

    private static int expectInvalidValue(int assertions) {
        try {
            new DeviceId("TENANT-ALPHA", null);
            throw new AssertionError("null value must fail");
        } catch (IllegalArgumentException expected) {
            return assertions + 1;
        }
    }

    private static int check(boolean condition, String message, int assertions) {
        if (!condition) {
            throw new AssertionError(message);
        }
        return assertions + 1;
    }
}
