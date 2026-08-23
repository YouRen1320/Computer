public final class InterfacesPolymorphismLab {
    private InterfacesPolymorphismLab() {
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
            return "SMS|AUDIT|" + workOrderId + "|" + message;
        }
    }

    static final class EmailSender extends ValidatingSender {
        @Override
        protected String deliver(String workOrderId, String message) {
            return "MAIL|AUDIT|" + workOrderId + "|" + message;
        }
    }

    static final class RecordingSender implements NotificationSender {
        private String observedWorkOrderId;
        private String observedMessage;

        @Override
        public String send(String workOrderId, String message) {
            requireText(workOrderId, "workOrderId");
            requireText(message, "message");
            observedWorkOrderId = workOrderId;
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

        assertions = verifyContract(sms, "SMS|", assertions);
        assertions = verifyContract(mail, "MAIL|", assertions);
        assertions = verifyContract(recording, "RECORDED|", assertions);

        String smsResult = new WorkOrderNotificationService(sms).notify("WO-1001", "inspect");
        String mailResult = new WorkOrderNotificationService(mail).notify("WO-1001", "inspect");
        String recordedResult = new WorkOrderNotificationService(recording).notify("WO-1001", "inspect");
        assertions = check("SMS|AUDIT|WO-1001|inspect".equals(smsResult), "sms", assertions);
        assertions = check("MAIL|AUDIT|WO-1001|inspect".equals(mailResult), "mail", assertions);
        assertions = check("RECORDED|WO-1001".equals(recordedResult), "recording", assertions);
        assertions = check("WO-1001".equals(recordingImplementation.observedWorkOrderId), "observed id", assertions);
        assertions = check("inspect".equals(recordingImplementation.observedMessage), "observed message", assertions);
        try {
            new WorkOrderNotificationService(null);
            throw new AssertionError("null dependency must fail");
        } catch (IllegalArgumentException expected) {
            assertions++;
        }

        System.out.println("sms=" + smsResult);
        System.out.println("mail=" + mailResult);
        System.out.println("recorded=" + recordedResult);
        System.out.println("runtime=" + sms.getClass().getSimpleName() + "," + mail.getClass().getSimpleName() + "," + recording.getClass().getSimpleName());
        System.out.println("service.calls=3");
        System.out.println("assertions=" + assertions + " passed");
    }

    private static int verifyContract(NotificationSender sender, String prefix, int assertions) {
        String result = sender.send("WO-C", "inspect");
        assertions = check(result.startsWith(prefix), "prefix", assertions);
        assertions = check(result.contains("WO-C"), "id retained", assertions);
        try {
            sender.send(" ", "inspect");
            throw new AssertionError("blank id must fail");
        } catch (IllegalArgumentException expected) {
            assertions++;
        }
        return assertions;
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
