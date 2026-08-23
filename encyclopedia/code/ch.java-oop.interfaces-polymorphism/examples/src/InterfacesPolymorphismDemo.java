public final class InterfacesPolymorphismDemo {
    private InterfacesPolymorphismDemo() {
    }

    interface NotificationSender {
        String send(String workOrderId, String message);

        default String contractName() {
            return "notification-v1";
        }
    }

    abstract static class AuditedSender implements NotificationSender {
        private final String channel;

        AuditedSender(String channel) {
            if (channel == null || channel.isBlank()) {
                throw new IllegalArgumentException("channel must have text");
            }
            this.channel = channel;
        }

        protected final String checkedPrefix(String workOrderId, String message) {
            requireText(workOrderId, "workOrderId");
            requireText(message, "message");
            return channel + "|AUDIT|" + workOrderId;
        }
    }

    static final class SmsSender extends AuditedSender {
        SmsSender() {
            super("SMS");
        }

        @Override
        public String send(String workOrderId, String message) {
            return checkedPrefix(workOrderId, message) + "|" + message;
        }
    }

    static final class EmailSender extends AuditedSender {
        EmailSender() {
            super("MAIL");
        }

        @Override
        public String send(String workOrderId, String message) {
            return checkedPrefix(workOrderId, message) + "|" + message;
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
        String mailResult = new WorkOrderNotificationService(mail).notify("WO-1002", "lubricate");
        String recordedResult = new WorkOrderNotificationService(recording).notify("WO-1003", "calibrate");
        assertions = check("SMS|AUDIT|WO-1001|inspect".equals(smsResult), "sms dispatch", assertions);
        assertions = check("MAIL|AUDIT|WO-1002|lubricate".equals(mailResult), "mail dispatch", assertions);
        assertions = check("RECORDED|WO-1003".equals(recordedResult), "recording dispatch", assertions);
        assertions = check("WO-1003".equals(recordingImplementation.observedWorkOrderId), "recorded id", assertions);
        assertions = check("calibrate".equals(recordingImplementation.observedMessage), "recorded message", assertions);
        assertions = check("notification-v1".equals(sms.contractName()), "default method", assertions);
        assertions = check(mail.getClass() == EmailSender.class, "runtime class", assertions);
        assertions = check(recording == recordingImplementation, "upcast keeps identity", assertions);

        System.out.println("sms=" + smsResult);
        System.out.println("mail=" + mailResult);
        System.out.println("recorded=" + recordedResult);
        System.out.println("contract=" + sms.contractName());
        System.out.println("runtime.mail=" + mail.getClass().getSimpleName());
        System.out.println("recording.observed=" + recordingImplementation.observedWorkOrderId + "|" + recordingImplementation.observedMessage);
        System.out.println("assertions=" + assertions + " passed");
    }

    private static int verifyContract(NotificationSender sender, String prefix, int assertions) {
        String result = sender.send("WO-C", "inspect");
        assertions = check(result.startsWith(prefix), "channel prefix", assertions);
        assertions = check(result.contains("WO-C"), "work order retained", assertions);
        try {
            sender.send(" ", "inspect");
            throw new AssertionError("blank work order must fail");
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
