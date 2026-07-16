public final class InheritanceCompositionDemo {
    private InheritanceCompositionDemo() {
    }

    static class NoticeFormatter {
        String render(String workOrderId, String summary) {
            requireText(workOrderId, "workOrderId");
            requireText(summary, "summary");
            return "NOTICE|" + workOrderId + "|" + summary;
        }

        final void requireText(String value, String field) {
            if (value == null || value.isBlank()) {
                throw new IllegalArgumentException(field + " must have text");
            }
        }
    }

    static final class SmsFormatter extends NoticeFormatter {
        @Override
        String render(String workOrderId, String summary) {
            return "SMS|" + super.render(workOrderId, summary);
        }
    }

    static final class MailFormatter extends NoticeFormatter {
        @Override
        String render(String workOrderId, String summary) {
            return "MAIL|" + super.render(workOrderId, summary);
        }
    }

    static final class WorkOrderNotifier {
        private final NoticeFormatter formatter;

        WorkOrderNotifier(NoticeFormatter formatter) {
            if (formatter == null) {
                throw new IllegalArgumentException("formatter required");
            }
            this.formatter = formatter;
        }

        String notify(String workOrderId, String summary) {
            return formatter.render(workOrderId, summary);
        }
    }

    public static void main(String[] args) {
        int assertions = 0;
        SmsFormatter smsFormatter = new SmsFormatter();
        String inherited = smsFormatter.render("WO-1001", "bearing-high-temperature");
        assertions = check(
                "SMS|NOTICE|WO-1001|bearing-high-temperature".equals(inherited),
                "child override keeps parent result",
                assertions);

        NoticeFormatter parentReference = smsFormatter;
        String parentUse = parentReference.render("WO-1001", "bearing-high-temperature");
        assertions = check(inherited.equals(parentUse), "parent use remains substitutable", assertions);

        WorkOrderNotifier smsNotifier = new WorkOrderNotifier(new SmsFormatter());
        WorkOrderNotifier mailNotifier = new WorkOrderNotifier(new MailFormatter());
        String sms = smsNotifier.notify("WO-1002", "lubrication-due");
        String mail = mailNotifier.notify("WO-1002", "lubrication-due");
        assertions = check("SMS|NOTICE|WO-1002|lubrication-due".equals(sms), "sms composition", assertions);
        assertions = check("MAIL|NOTICE|WO-1002|lubrication-due".equals(mail), "mail composition", assertions);
        assertions = check(!sms.equals(mail), "dependency changes one concern", assertions);
        assertions = check(sms.contains("NOTICE|"), "sms calls super", assertions);
        assertions = check(mail.contains("NOTICE|"), "mail calls super", assertions);
        assertions = expectBlankWorkOrderFailure(smsNotifier, assertions);

        System.out.println("inheritance=" + inherited);
        System.out.println("parentUse=" + parentUse);
        System.out.println("composition.sms=" + sms);
        System.out.println("composition.mail=" + mail);
        System.out.println("dependency.changed=" + !sms.equals(mail));
        System.out.println("assertions=" + assertions + " passed");
    }

    private static int check(boolean condition, String message, int assertions) {
        if (!condition) {
            throw new AssertionError(message);
        }
        return assertions + 1;
    }

    private static int expectBlankWorkOrderFailure(WorkOrderNotifier notifier, int assertions) {
        try {
            notifier.notify(" ", "lubrication-due");
            throw new AssertionError("expected parent validation failure");
        } catch (IllegalArgumentException expected) {
            return assertions + 1;
        }
    }
}
