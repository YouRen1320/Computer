public final class NotificationPolymorphismChallenge {
    interface NotificationSender {
        String send(String workOrderId, String message);
    }

    static final class SmsSender implements NotificationSender {
        @Override
        public String send(String workOrderId, String message) {
            return "SMS|" + workOrderId + "|" + message;
        }
    }

    static final class EmailSender implements NotificationSender {
        @Override
        public String send(String workOrderId, String message) {
            return "MAIL|" + workOrderId + "|" + message;
        }
    }

    static final class RecordingSender implements NotificationSender {
        @Override
        public String send(String workOrderId, String message) {
            return "RECORDED|" + workOrderId;
        }
    }

    static final class WorkOrderNotificationService {
        // TODO: depend on NotificationSender and call its contract directly.
        private final Object sender;

        WorkOrderNotificationService(Object sender) {
            this.sender = sender;
        }

        String notify(String workOrderId, String message) {
            if (sender instanceof SmsSender) {
                return ((SmsSender) sender).send(workOrderId, message);
            }
            if (sender instanceof EmailSender) {
                return ((EmailSender) sender).send(workOrderId, message);
            }
            throw new IllegalArgumentException("unsupported sender");
        }
    }

    public static void main(String[] args) {
        try {
            new WorkOrderNotificationService(new RecordingSender()).notify("WO-1001", "inspect");
            throw new AssertionError("starter should expose missing third implementation");
        } catch (IllegalArgumentException expected) {
            System.err.println("STARTER_THIRD_IMPLEMENTATION_FAILURE implementation=RecordingSender reason=type-branch");
            System.exit(9);
        }
    }
}
