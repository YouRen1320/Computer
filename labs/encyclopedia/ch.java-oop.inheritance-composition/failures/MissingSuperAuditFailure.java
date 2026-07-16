public final class MissingSuperAuditFailure {
    static class NotificationFormatter {
        String format(String workOrderId) {
            return "TENANT-A|AUDIT|" + workOrderId;
        }
    }

    static final class SmsFormatter extends NotificationFormatter {
        @Override
        String format(String workOrderId) {
            return "SMS|" + workOrderId;
        }
    }

    public static void main(String[] args) {
        String actual = new SmsFormatter().format("WO-1001");
        String expected = "SMS|TENANT-A|AUDIT|WO-1001";
        if (!expected.equals(actual)) {
            System.err.println("BASE_AUDIT_LOST expected=" + expected + " actual=" + actual);
            System.exit(7);
        }
    }
}
