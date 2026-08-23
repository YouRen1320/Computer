public final class NotificationPolymorphismSolution {
    private NotificationPolymorphismSolution() {
    }

    interface NotificationSender {
        String send(String workOrderId, String message);
    }

    abstract static class ValidatingSender implements NotificationSender {
        @Override
        public final String send(String workOrderId, String message) {
            requireText(workOrderId, "workOrderId");
            requireText(message, "message");
            return deliver(workOrderId, message);
        }

        protected abstract String deliver(String workOrderId, String message);
    }

    static final class SmsSender extends ValidatingSender {
        @Override
        protected String deliver(String workOrderId, String message) {
            return "SMS|" + workOrderId + "|" + message;
        }
    }

    static final class EmailSender extends ValidatingSender {
        @Override
        protected String deliver(String workOrderId, String message) {
            return "MAIL|" + workOrderId + "|" + message;
        }
    }

    static final class RecordingSender implements NotificationSender {
        private String observedId;
        private String observedMessage;

        @Override
        public String send(String workOrderId, String message) {
            requireText(workOrderId, "workOrderId");
            requireText(message, "message");
            observedId = workOrderId;
            observedMessage = message;
            return "RECORDED|" + workOrderId;
        }
    }

    static final class WorkOrderNotificationService {
        private final NotificationSender sender;

        WorkOrderNotificationService(NotificationSender sender) {
            if (sender == null) {
                throw new IllegalArgumentException("sender required");
            }
            this.sender = sender;
        }

        String notify(String workOrderId, String message) {
            return sender.send(workOrderId, message);
        }
    }

    public static void main(String[] args) {
        int assertions = 0;
        NotificationSender sms = new SmsSender();
        NotificationSender mail = new EmailSender();
        RecordingSender recordingImplementation = new RecordingSender();
        NotificationSender recording = recordingImplementation;

        String smsResult = new WorkOrderNotificationService(sms).notify("WO-1001", "inspect");
        String mailResult = new WorkOrderNotificationService(mail).notify("WO-1001", "inspect");
        String recordedResult = new WorkOrderNotificationService(recording).notify("WO-1001", "inspect");
        assertions = check("SMS|WO-1001|inspect".equals(smsResult), "sms", assertions);
        assertions = check("MAIL|WO-1001|inspect".equals(mailResult), "mail", assertions);
        assertions = check("RECORDED|WO-1001".equals(recordedResult), "recorded", assertions);
        assertions = check("WO-1001".equals(recordingImplementation.observedId), "id", assertions);
        assertions = check("inspect".equals(recordingImplementation.observedMessage), "message", assertions);
        assertions = expectBlankFailure(sms, assertions);
        assertions = expectBlankFailure(mail, assertions);
        assertions = expectBlankFailure(recording, assertions);
        assertions = check(sms.getClass() == SmsSender.class, "sms runtime", assertions);
        assertions = check(mail.getClass() == EmailSender.class, "mail runtime", assertions);
        assertions = check(recording == recordingImplementation, "identity", assertions);
        try {
            new WorkOrderNotificationService(null);
            throw new AssertionError("null dependency must fail");
        } catch (IllegalArgumentException expected) {
            assertions++;
        }

        System.out.println("solution.sms=" + smsResult);
        System.out.println("solution.mail=" + mailResult);
        System.out.println("solution.recorded=" + recordedResult);
        System.out.println("solution.serviceBranches=0");
        System.out.println("solution.assertions=" + assertions + " passed");
    }

    private static int expectBlankFailure(NotificationSender sender, int assertions) {
        try {
            sender.send(" ", "inspect");
            throw new AssertionError("blank id must fail");
        } catch (IllegalArgumentException expected) {
            return assertions + 1;
        }
    }

    private static void requireText(String value, String field) {
        if (value == null || value.isBlank()) {
            throw new IllegalArgumentException(field + " must have text");
        }
    }

    private static int check(boolean condition, String message, int assertions) {
        if (!condition) {
            throw new AssertionError(message);
        }
        return assertions + 1;
    }
}
