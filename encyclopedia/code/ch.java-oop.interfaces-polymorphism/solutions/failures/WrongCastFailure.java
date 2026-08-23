public final class WrongCastFailure {
    interface Sender { String send(); }
    static final class SmsSender implements Sender { public String send() { return "SMS"; } }
    static final class EmailSender implements Sender { public String send() { return "MAIL"; } }

    public static void main(String[] args) {
        Sender sender = new EmailSender();
        try {
            SmsSender ignored = (SmsSender) sender;
            throw new AssertionError("cast unexpectedly succeeded: " + ignored);
        } catch (ClassCastException expected) {
            System.err.println("SOLUTION_WRONG_CAST actual=EmailSender target=SmsSender exception=ClassCastException");
            System.exit(10);
        }
    }
}
