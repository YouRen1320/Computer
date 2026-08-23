public final class ThirdImplementationBranchFailure {
    interface NotificationSender { String send(); }
    static final class SmsSender implements NotificationSender { public String send() { return "SMS"; } }
    static final class EmailSender implements NotificationSender { public String send() { return "MAIL"; } }
    static final class RecordingSender implements NotificationSender { public String send() { return "RECORDED"; } }

    static String brokenService(NotificationSender sender) {
        if (sender instanceof SmsSender) return "SMS";
        if (sender instanceof EmailSender) return "MAIL";
        throw new IllegalArgumentException("unsupported implementation");
    }

    public static void main(String[] args) {
        try {
            brokenService(new RecordingSender());
            throw new AssertionError("expected missing third branch");
        } catch (IllegalArgumentException expected) {
            System.err.println("LAB_TYPE_BRANCH_BROKEN implementation=RecordingSender");
            System.exit(7);
        }
    }
}
