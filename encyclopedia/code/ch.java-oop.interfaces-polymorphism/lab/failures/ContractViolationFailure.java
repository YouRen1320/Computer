public final class ContractViolationFailure {
    interface NotificationSender { String send(String workOrderId); }

    static final class BlankAcceptingSender implements NotificationSender {
        @Override
        public String send(String workOrderId) {
            return "RECORDED|" + workOrderId;
        }
    }

    public static void main(String[] args) {
        NotificationSender sender = new BlankAcceptingSender();
        try {
            sender.send(" ");
            System.err.println("LAB_CONTRACT_BROKEN input=blank expected=IllegalArgumentException actual=success");
            System.exit(8);
        } catch (IllegalArgumentException expected) {
            throw new AssertionError("fixture must demonstrate violation");
        }
    }
}
