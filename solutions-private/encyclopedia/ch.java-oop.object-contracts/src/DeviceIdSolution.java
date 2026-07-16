public final class DeviceIdSolution {
    private DeviceIdSolution() {
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
            if (other == null || getClass() != other.getClass()) {
                return false;
            }
            DeviceId that = (DeviceId) other;
            return tenantId.equals(that.tenantId) && value.equals(that.value);
        }

        @Override
        public int hashCode() {
            return 31 * tenantId.hashCode() + value.hashCode();
        }

        @Override
        public String toString() {
            return "DeviceId[tenant=<redacted>, value=" + value + "]";
        }

        private static String normalize(String input, String field) {
            if (input == null || input.isBlank()) {
                throw new IllegalArgumentException(field + " must have text");
            }
            return input.trim().toUpperCase();
        }
    }

    public static void main(String[] args) {
        int assertions = 0;
        DeviceId first = new DeviceId("TENANT-ALPHA", "DEV-001");
        DeviceId second = new DeviceId("TENANT-ALPHA", "DEV-001");
        DeviceId third = new DeviceId(" tenant-alpha ", " dev-001 ");
        DeviceId otherTenant = new DeviceId("TENANT-BETA", "DEV-001");
        DeviceId otherValue = new DeviceId("TENANT-ALPHA", "DEV-002");

        assertions = check(first.equals(first), "reflexive", assertions);
        assertions = check(first.equals(second), "equal values", assertions);
        assertions = check(second.equals(first), "symmetric", assertions);
        assertions = check(first.equals(second) && second.equals(third) && first.equals(third),
                "transitive", assertions);
        assertions = check(first.equals(second), "consistent first", assertions);
        assertions = check(first.equals(second), "consistent second", assertions);
        assertions = check(!first.equals(null), "null false", assertions);
        assertions = check(!first.equals("DEV-001"), "different type false", assertions);
        assertions = check(!first.equals(otherTenant), "tenant participates", assertions);
        assertions = check(!first.equals(otherValue), "value participates", assertions);
        assertions = check(first.hashCode() == second.hashCode(), "equal hash", assertions);
        assertions = check(second.hashCode() == third.hashCode(), "normalized equal hash", assertions);

        String text = first.toString();
        assertions = check("DeviceId[tenant=<redacted>, value=DEV-001]".equals(text), "safe text", assertions);
        assertions = check(!text.contains("TENANT-ALPHA"), "tenant hidden", assertions);
        assertions = expectInvalid(" ", "DEV-001", assertions);
        assertions = expectInvalid("TENANT-ALPHA", null, assertions);

        System.out.println("solution.report=INPUT two equal DeviceId values | OP equals/hashCode | RESULT equals="
                + first.equals(second) + ", hashesEqual=" + (first.hashCode() == second.hashCode()));
        System.out.println("solution.text=" + text);
        System.out.println("solution.assertions=" + assertions + " passed");
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
