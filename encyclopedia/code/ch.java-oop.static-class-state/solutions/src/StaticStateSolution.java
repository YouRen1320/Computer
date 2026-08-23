public final class StaticStateSolution {
    private StaticStateSolution() {
    }

    private static final class TicketIds {
        private int next;

        TicketIds(int first) {
            if (first < 1) {
                throw new IllegalArgumentException("first must be positive");
            }
            next = first;
        }

        String nextId(String siteCode) {
            if (siteCode == null || siteCode.isBlank()) {
                throw new IllegalArgumentException("siteCode must have text");
            }
            return format(siteCode, next++);
        }

        private static String format(String siteCode, int sequence) {
            return "%s-%04d".formatted(siteCode, sequence);
        }
    }

    public static void main(String[] args) {
        TicketIds nc = new TicketIds(1);
        TicketIds nj = new TicketIds(1);
        int assertions = 0;
        assertions = check("NC-0001".equals(nc.nextId("NC")), "NC first", assertions);
        assertions = check("NJ-0001".equals(nj.nextId("NJ")), "NJ first", assertions);
        assertions = check("NC-0002".equals(nc.nextId("NC")), "NC second", assertions);
        assertions = check("NJ-0002".equals(nj.nextId("NJ")), "NJ second", assertions);
        assertions = expectIllegal(() -> new TicketIds(0), "invalid first", assertions);
        assertions = expectIllegal(() -> nc.nextId(" "), "blank site", assertions);
        TicketIds replay = new TicketIds(1);
        assertions = check("NC-0001".equals(replay.nextId("NC")), "fresh replay", assertions);
        assertions = check("NC-0003".equals(nc.nextId("NC")), "NC keeps local history", assertions);
        System.out.println("solution.assertions=" + assertions + " passed");
    }

    private static int check(boolean condition, String message, int assertions) {
        if (!condition) {
            throw new AssertionError(message);
        }
        return assertions + 1;
    }

    private static int expectIllegal(Action action, String message, int assertions) {
        try {
            action.run();
            throw new AssertionError("expected IllegalArgumentException: " + message);
        } catch (IllegalArgumentException expected) {
            return assertions + 1;
        }
    }

    @FunctionalInterface
    private interface Action {
        void run();
    }
}
