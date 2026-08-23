public final class MissingSuperFailure {
    static class NoticeFormatter {
        String render(String workOrderId) {
            return "AUDIT|" + workOrderId;
        }
    }

    static final class SmsFormatter extends NoticeFormatter {
        @Override
        String render(String workOrderId) {
            return "SMS|" + workOrderId;
        }
    }

    public static void main(String[] args) {
        String actual = new SmsFormatter().render("WO-1001");
        String expected = "SMS|AUDIT|WO-1001";
        if (!expected.equals(actual)) {
            System.err.println("SUPER_CALL_MISSING expected=" + expected + " actual=" + actual);
            System.exit(5);
        }
    }
}
