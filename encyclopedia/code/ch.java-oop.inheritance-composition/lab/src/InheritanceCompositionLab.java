public final class InheritanceCompositionLab {
    private InheritanceCompositionLab() {
    }

    static class NotificationFormatter {
        String format(String workOrderId, String priority) {
            requireText(workOrderId, "workOrderId");
            requireText(priority, "priority");
            if (!priority.equals("NORMAL") && !priority.equals("URGENT")) {
                throw new IllegalArgumentException("unsupported priority");
            }
            return "WORK_ORDER|" + workOrderId + "|" + priority;
        }

        private static void requireText(String value, String field) {
            if (value == null || value.isBlank()) {
                throw new IllegalArgumentException(field + " must have text");
            }
        }
    }

    static final class SmsFormatter extends NotificationFormatter {
        @Override
        String format(String workOrderId, String priority) {
            return "SMS|" + super.format(workOrderId, priority);
        }
    }

    static final class MailFormatter extends NotificationFormatter {
        @Override
        String format(String workOrderId, String priority) {
            return "MAIL|" + super.format(workOrderId, priority);
        }
    }

    static final class RecordingFormatter extends NotificationFormatter {
        private String observedId;
        private String observedPriority;

        @Override
        String format(String workOrderId, String priority) {
            String base = super.format(workOrderId, priority);
            observedId = workOrderId;
            observedPriority = priority;
            return "RECORDED|" + base;
        }
    }

    static final class WorkOrderNotifier {
        private final NotificationFormatter formatter;

        WorkOrderNotifier(NotificationFormatter formatter) {
            if (formatter == null) {
                throw new IllegalArgumentException("formatter required");
            }
            this.formatter = formatter;
        }

        String notify(String workOrderId, String priority) {
            return formatter.format(workOrderId, priority);
        }
    }

    public static void main(String[] args) {
        int assertions = 0;
        SmsFormatter smsFormatter = new SmsFormatter();
        MailFormatter mailFormatter = new MailFormatter();
        assertions = verifyParentContract(smsFormatter, "SMS", assertions);
        assertions = verifyParentContract(mailFormatter, "MAIL", assertions);

        WorkOrderNotifier smsNotifier = new WorkOrderNotifier(smsFormatter);
        WorkOrderNotifier mailNotifier = new WorkOrderNotifier(mailFormatter);
        String sms = smsNotifier.notify("WO-1001", "NORMAL");
        String mail = mailNotifier.notify("WO-1001", "NORMAL");
        assertions = check("SMS|WORK_ORDER|WO-1001|NORMAL".equals(sms), "sms output", assertions);
        assertions = check("MAIL|WORK_ORDER|WO-1001|NORMAL".equals(mail), "mail output", assertions);

        RecordingFormatter recording = new RecordingFormatter();
        WorkOrderNotifier recordingNotifier = new WorkOrderNotifier(recording);
        String recorded = recordingNotifier.notify("WO-1009", "URGENT");
        assertions = check("WO-1009".equals(recording.observedId), "id delegated", assertions);
        assertions = check("URGENT".equals(recording.observedPriority), "priority delegated", assertions);
        assertions = check("RECORDED|WORK_ORDER|WO-1009|URGENT".equals(recorded), "recording result", assertions);
        assertions = expectNullDependencyFailure(assertions);

        System.out.println("sms=" + sms);
        System.out.println("mail=" + mail);
        System.out.println("recorded=" + recorded);
        System.out.println("replacement.independent=true");
        System.out.println("assertions=" + assertions + " passed");
    }

    private static int verifyParentContract(
            NotificationFormatter formatter, String expectedChannel, int assertions) {
        String normal = formatter.format("WO-1", "NORMAL");
        String urgent = formatter.format("WO-2", "URGENT");
        assertions = check(normal.equals(expectedChannel + "|WORK_ORDER|WO-1|NORMAL"), "normal", assertions);
        assertions = check(urgent.equals(expectedChannel + "|WORK_ORDER|WO-2|URGENT"), "urgent", assertions);
        assertions = expectFormatFailure(formatter, " ", "NORMAL", assertions);
        assertions = expectFormatFailure(formatter, "WO-3", "UNKNOWN", assertions);
        return assertions;
    }

    private static int check(boolean condition, String message, int assertions) {
        if (!condition) {
            throw new AssertionError(message);
        }
        return assertions + 1;
    }

    private static int expectFormatFailure(
            NotificationFormatter formatter, String workOrderId, String priority, int assertions) {
        try {
            formatter.format(workOrderId, priority);
            throw new AssertionError("expected formatter failure");
        } catch (IllegalArgumentException expected) {
            return assertions + 1;
        }
    }

    private static int expectNullDependencyFailure(int assertions) {
        try {
            new WorkOrderNotifier(null);
            throw new AssertionError("expected null dependency failure");
        } catch (IllegalArgumentException expected) {
            return assertions + 1;
        }
    }
}
