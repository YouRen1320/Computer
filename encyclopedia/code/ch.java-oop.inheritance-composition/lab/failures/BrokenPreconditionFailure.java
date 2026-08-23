public final class BrokenPreconditionFailure {
    static class NotificationFormatter {
        String format(String priority) {
            if (!priority.equals("NORMAL") && !priority.equals("URGENT")) {
                throw new IllegalArgumentException("unsupported priority");
            }
            return priority;
        }
    }

    static final class UrgentOnlyFormatter extends NotificationFormatter {
        @Override
        String format(String priority) {
            if (!priority.equals("URGENT")) {
                throw new IllegalArgumentException("urgent only");
            }
            return super.format(priority);
        }
    }

    public static void main(String[] args) {
        String parent = new NotificationFormatter().format("NORMAL");
        if (!"NORMAL".equals(parent)) {
            throw new AssertionError("fixture parent must accept NORMAL");
        }
        try {
            useAsParent(new UrgentOnlyFormatter(), "NORMAL");
            throw new AssertionError("expected substitution failure");
        } catch (IllegalArgumentException expected) {
            System.err.println("PARENT_CONTRACT_BROKEN input=NORMAL parent=accepted child=rejected");
            System.exit(6);
        }
    }

    private static String useAsParent(NotificationFormatter formatter, String priority) {
        return formatter.format(priority);
    }
}
