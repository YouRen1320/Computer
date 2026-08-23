public final class WrongCastFailure {
    interface NotificationSender {
        String send();
    }

    static final class SmsSender implements NotificationSender {
        @Override
        public String send() {
            return "SMS";
        }
    }

    static final class EmailSender implements NotificationSender {
        @Override
        public String send() {
            return "MAIL";
        }
    }

    public static void main(String[] args) {
        NotificationSender sender = new EmailSender();
        try {
            SmsSender ignored = (SmsSender) sender;
            throw new AssertionError("cast unexpectedly succeeded: " + ignored);
        } catch (ClassCastException expected) {
            System.err.println("WRONG_CAST actual=EmailSender target=SmsSender exception=ClassCastException");
            System.exit(4);
        }
    }
}
