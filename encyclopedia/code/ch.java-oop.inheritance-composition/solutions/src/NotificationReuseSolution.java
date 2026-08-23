public final class NotificationReuseSolution {
    private NotificationReuseSolution() {
    }

    static class NotificationFormatter {
        String format(String workOrderId, String priority) {
            if (workOrderId == null || workOrderId.isBlank()) {
                throw new IllegalArgumentException("workOrderId must have text");
            }
            if (!priority.equals("NORMAL") && !priority.equals("URGENT")) {
                throw new IllegalArgumentException("unsupported priority");
            }
            return "WORK_ORDER|" + workOrderId + "|" + priority;
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
        NotificationFormatter smsAsParent = new SmsFormatter();
        NotificationFormatter mailAsParent = new MailFormatter();
        String smsParent = smsAsParent.format("WO-1", "NORMAL");
        String mailParent = mailAsParent.format("WO-1", "NORMAL");
        assertions = check("SMS|WORK_ORDER|WO-1|NORMAL".equals(smsParent), "sms parent", assertions);
        assertions = check("MAIL|WORK_ORDER|WO-1|NORMAL".equals(mailParent), "mail parent", assertions);
        assertions = check(smsParent.contains("WORK_ORDER|"), "sms super", assertions);
        assertions = check(mailParent.contains("WORK_ORDER|"), "mail super", assertions);

        WorkOrderNotifier sms = new WorkOrderNotifier(new SmsFormatter());
        WorkOrderNotifier mail = new WorkOrderNotifier(new MailFormatter());
        assertions = check(
                "SMS|WORK_ORDER|WO-1001|URGENT".equals(sms.notify("WO-1001", "URGENT")),
                "sms composition",
                assertions);
        assertions = check(
                "MAIL|WORK_ORDER|WO-1001|URGENT".equals(mail.notify("WO-1001", "URGENT")),
                "mail composition",
                assertions);
        assertions = expectNotifyFailure(sms, " ", "NORMAL", assertions);
        assertions = expectNotifyFailure(mail, "WO-2", "UNKNOWN", assertions);
        assertions = expectNullDependencyFailure(assertions);
        assertions = check(
                NotificationFormatter.class.isAssignableFrom(WorkOrderNotifier.class) == false,
                "service is not a formatter subtype",
                assertions);

        System.out.println("solution.sms=" + sms.notify("WO-1001", "URGENT"));
        System.out.println("solution.mail=" + mail.notify("WO-1001", "URGENT"));
        System.out.println("solution.relationship=has-a");
        System.out.println("solution.assertions=" + assertions + " passed");
    }

    private static int check(boolean condition, String message, int assertions) {
        if (!condition) {
            throw new AssertionError(message);
        }
        return assertions + 1;
    }

    private static int expectNotifyFailure(
            WorkOrderNotifier notifier, String workOrderId, String priority, int assertions) {
        try {
            notifier.notify(workOrderId, priority);
            throw new AssertionError("expected notification failure");
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
