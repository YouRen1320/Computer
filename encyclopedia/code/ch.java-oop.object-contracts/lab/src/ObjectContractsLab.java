public final class ObjectContractsLab {
    private ObjectContractsLab() {
    }

    /** 生产值对象只暴露安全诊断表示；租户字段仍参与相等与哈希。 */
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

    record ContractReport(String input, String operation, String result) {
        String render() {
            return "INPUT " + input + " | OP " + operation + " | RESULT " + result;
        }
    }

    public static void main(String[] args) {
        int assertions = 0;
        DeviceId first = new DeviceId("tenant-alpha", "dev-001");
        DeviceId second = new DeviceId("TENANT-ALPHA", "DEV-001");
        DeviceId third = new DeviceId(" TENANT-ALPHA ", " DEV-001 ");
        DeviceId otherTenant = new DeviceId("TENANT-BETA", "DEV-001");
        DeviceId otherValue = new DeviceId("TENANT-ALPHA", "DEV-002");

        assertions = check(first != second, "identity differs", assertions);
        assertions = check(first.equals(first), "reflexive", assertions);
        assertions = check(first.equals(second), "normalized values equal", assertions);
        assertions = check(second.equals(first), "symmetric", assertions);
        assertions = check(first.equals(second) && second.equals(third) && first.equals(third),
                "transitive", assertions);
        assertions = check(first.equals(second), "consistent call one", assertions);
        assertions = check(first.equals(second), "consistent call two", assertions);
        assertions = check(!first.equals(null), "null false", assertions);
        assertions = check(!first.equals("DEV-001"), "different type false", assertions);
        assertions = check(!first.equals(otherTenant), "tenant separates values", assertions);
        assertions = check(!first.equals(otherValue), "device value separates values", assertions);
        assertions = check(first.hashCode() == second.hashCode(), "equal values equal hash", assertions);
        assertions = check(second.hashCode() == third.hashCode(), "transitive values equal hash", assertions);

        String text = first.toString();
        assertions = check("DeviceId[tenant=<redacted>, value=DEV-001]".equals(text),
                "safe text shape", assertions);
        assertions = check(!text.contains("TENANT-ALPHA"), "tenant absent", assertions);
        assertions = check(text.contains("DEV-001"), "safe value present", assertions);

        ContractReport equalsReport = new ContractReport("two normalized DeviceId values", "equals", "true");
        ContractReport hashReport = new ContractReport("two equal DeviceId values", "hashCode equality", "true");
        assertions = check(equalsReport.render().endsWith("RESULT true"), "equals report result", assertions);
        assertions = check(hashReport.render().contains("OP hashCode equality"), "hash report operation", assertions);
        assertions = expectInvalid(" ", "DEV-001", assertions);
        assertions = expectInvalid("TENANT-ALPHA", null, assertions);

        ContractReport textReport = new ContractReport("one DeviceId", "toString", text);
        System.out.println("report.equals=" + equalsReport.render());
        System.out.println("report.hash=" + hashReport.render());
        System.out.println("report.text=" + textReport.render());
        System.out.println("identityEqual=" + (first == second));
        System.out.println("valueEqual=" + first.equals(second));
        System.out.println("otherTenantEqual=" + first.equals(otherTenant));
        System.out.println("assertions=" + assertions + " passed");
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
