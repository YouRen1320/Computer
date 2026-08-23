public final class TypeBranchFailure {
    interface NotificationSender {
        String send();
    }

    static final class SmsSender implements NotificationSender {
        public String send() { return "SMS"; }
    }

    static final class EmailSender implements NotificationSender {
        public String send() { return "MAIL"; }
    }

    static final class RecordingSender implements NotificationSender {
        public String send() { return "RECORDED"; }
    }

    static String brokenDispatch(NotificationSender sender) {
        if (sender instanceof SmsSender) {
            return "SMS";
        }
        if (sender instanceof EmailSender) {
            return "MAIL";
        }
        throw new IllegalArgumentException("unsupported implementation");
    }

    public static void main(String[] args) {
        try {
            brokenDispatch(new RecordingSender());
            throw new AssertionError("third implementation should expose branch failure");
        } catch (IllegalArgumentException expected) {
            System.err.println("TYPE_BRANCH_BROKEN implementation=RecordingSender reason=unsupported");
            System.exit(5);
        }
    }
}
