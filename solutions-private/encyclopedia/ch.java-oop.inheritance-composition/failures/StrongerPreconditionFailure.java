public final class StrongerPreconditionFailure {
    static class Formatter {
        String format(String priority) {
            return priority;
        }
    }

    static final class UrgentOnly extends Formatter {
        @Override
        String format(String priority) {
            if (!priority.equals("URGENT")) {
                throw new IllegalArgumentException("urgent only");
            }
            return super.format(priority);
        }
    }

    public static void main(String[] args) {
        new Formatter().format("NORMAL");
        try {
            useAsParent(new UrgentOnly(), "NORMAL");
            throw new AssertionError("expected stronger precondition failure");
        } catch (IllegalArgumentException expected) {
            System.err.println("SOLUTION_FAULT_REPLAY input=NORMAL parent=accepted child=rejected");
            System.exit(9);
        }
    }

    private static String useAsParent(Formatter formatter, String priority) {
        return formatter.format(priority);
    }
}
