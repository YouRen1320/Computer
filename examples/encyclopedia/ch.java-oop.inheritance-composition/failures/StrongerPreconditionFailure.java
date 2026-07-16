public final class StrongerPreconditionFailure {
    static class NoticeFormatter {
        String render(String workOrderId) {
            if (workOrderId == null || workOrderId.isBlank()) {
                throw new IllegalArgumentException("workOrderId must have text");
            }
            return "NOTICE|" + workOrderId;
        }
    }

    static final class StrictSmsFormatter extends NoticeFormatter {
        @Override
        String render(String workOrderId) {
            if (workOrderId.length() < 8) {
                throw new IllegalArgumentException("workOrderId must contain at least 8 characters");
            }
            return "SMS|" + super.render(workOrderId);
        }
    }

    public static void main(String[] args) {
        String fixedInput = "WO-1";
        String parentResult = new NoticeFormatter().render(fixedInput);
        if (!"NOTICE|WO-1".equals(parentResult)) {
            throw new AssertionError("fixture parent must accept WO-1");
        }
        try {
            useAsParent(new StrictSmsFormatter(), fixedInput);
            throw new AssertionError("expected child to expose broken substitution");
        } catch (IllegalArgumentException expected) {
            System.err.println("SUBSTITUTION_BROKEN input=WO-1 parent=accepted child=rejected");
            System.exit(4);
        }
    }

    private static String useAsParent(NoticeFormatter formatter, String input) {
        return formatter.render(input);
    }
}
