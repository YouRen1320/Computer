public final class NotificationReuseChallenge {
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

    static class SmsFormatter extends NotificationFormatter {
        @Override
        String format(String workOrderId, String priority) {
            return "SMS|" + super.format(workOrderId, priority);
        }
    }

    // TODO: WorkOrderNotifier is not a kind of SmsFormatter. Replace this fake is-a
    // relationship with a private final formatter field supplied by the constructor.
    static final class WorkOrderNotifier extends SmsFormatter {
        @Override
        String format(String workOrderId, String priority) {
            if (!priority.equals("URGENT")) {
                throw new IllegalArgumentException("starter only accepts URGENT");
            }
            return super.format(workOrderId, priority);
        }

        String notify(String workOrderId, String priority) {
            return format(workOrderId, priority);
        }
    }

    public static void main(String[] args) {
        NotificationFormatter parent = new NotificationFormatter();
        String parentResult = parent.format("WO-1001", "NORMAL");
        if (!"WORK_ORDER|WO-1001|NORMAL".equals(parentResult)) {
            throw new AssertionError("fixture parent must accept NORMAL");
        }
        try {
            new WorkOrderNotifier().notify("WO-1001", "NORMAL");
            throw new AssertionError("starter should expose stronger precondition");
        } catch (IllegalArgumentException expected) {
            System.err.println("STARTER_SUBSTITUTION_FAILURE input=NORMAL parent=accepted child=rejected");
            System.exit(8);
        }
    }
}
