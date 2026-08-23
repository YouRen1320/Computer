public final class DeviceIdChallenge {
    private DeviceIdChallenge() {
    }

    static final class DeviceId {
        private final String tenantId;
        private final String value;

        DeviceId(String tenantId, String value) {
            this.tenantId = normalize(tenantId, "tenantId");
            this.value = normalize(value, "value");
        }

        @Override
        public boolean equals(Object other) {
            if (this == other) {
                return true;
            }
            if (!(other instanceof DeviceId that)) {
                return false;
            }
            // TODO：决定 DeviceId 的完整值边界，并让这里与 hashCode 使用相同字段集合。
            return value.equals(that.value);
        }

        @Override
        public int hashCode() {
            return 31 * tenantId.hashCode() + value.hashCode();
        }

        @Override
        public String toString() {
            // TODO：保留排障所需信息，同时移除敏感租户值。
            return "DeviceId[tenant=" + tenantId + ", value=" + value + "]";
        }

        private static String normalize(String input, String field) {
            if (input == null || input.isBlank()) {
                throw new IllegalArgumentException(field + " must have text");
            }
            return input.trim().toUpperCase();
        }
    }

    public static void main(String[] args) {
        DeviceId first = new DeviceId("TENANT-ALPHA", "DEV-001");
        DeviceId same = new DeviceId("TENANT-ALPHA", "DEV-001");
        DeviceId third = new DeviceId(" TENANT-ALPHA ", " dev-001 ");
        DeviceId otherTenant = new DeviceId("TENANT-BETA", "DEV-001");
        DeviceId otherValue = new DeviceId("TENANT-ALPHA", "DEV-002");

        boolean crossTenantEqual = first.equals(otherTenant);
        boolean crossTenantHashesEqual = first.hashCode() == otherTenant.hashCode();
        if (crossTenantEqual && !crossTenantHashesEqual) {
            System.err.println("STARTER_HASH_CONTRACT_FAILURE equal=true hashesEqual=false");
            System.exit(8);
        }

        String text = first.toString();
        if (text.contains("TENANT-ALPHA")) {
            System.err.println("STARTER_TOSTRING_LEAK field=tenantId canaryDetected=true");
            System.exit(9);
        }

        int assertions = 0;
        assertions = check(first.equals(first), "reflexive", assertions);
        assertions = check(first.equals(same), "equal values", assertions);
        assertions = check(same.equals(first), "symmetric", assertions);
        assertions = check(first.equals(same) && same.equals(third) && first.equals(third),
                "transitive", assertions);
        assertions = check(first.equals(same), "consistent first", assertions);
        assertions = check(first.equals(same), "consistent second", assertions);
        assertions = check(!first.equals(null), "null false", assertions);
        assertions = check(!first.equals("DEV-001"), "different type false", assertions);
        assertions = check(!first.equals(otherTenant), "tenant participates", assertions);
        assertions = check(!first.equals(otherValue), "value participates", assertions);
        assertions = check(first.hashCode() == same.hashCode(), "equal hash", assertions);
        assertions = check(same.hashCode() == third.hashCode(), "normalized equal hash", assertions);
        assertions = check("DeviceId[tenant=<redacted>, value=DEV-001]".equals(text), "safe text", assertions);
        assertions = check(!text.contains("TENANT-ALPHA"), "tenant hidden", assertions);
        assertions = expectInvalid("", "DEV-001", assertions);
        assertions = expectInvalid("TENANT-ALPHA", null, assertions);
        System.out.println("challenge.text=" + text);
        System.out.println("challenge.assertions=" + assertions + " passed");
    }

    private static int expectInvalid(String tenantId, String value, int assertions) {
        try {
            new DeviceId(tenantId, value);
            throw new AssertionError("invalid input must fail");
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
