public final class StaticStateChallenge {
    private StaticStateChallenge() {
    }

    private static final class TicketIds {
        private static int next = 1;

        static String nextId() {
            return "WO-%04d".formatted(next++);
        }
    }

    public static void main(String[] args) {
        int assertions = 0;
        String firstScenario = TicketIds.nextId();
        assertions = check("WO-0001".equals(firstScenario), "first scenario", assertions);

        String secondScenario = TicketIds.nextId();
        if (!"WO-0001".equals(secondScenario)) {
            System.err.println("STARTER_ORDER_DEPENDENCY expected=WO-0001 actual=" + secondScenario);
            System.exit(1);
        }

        assertions = check("WO-0001".equals(secondScenario), "second scenario", assertions);
        assertions = check(firstScenario.equals(secondScenario), "independent starts", assertions);
        assertions = check(firstScenario.startsWith("WO-"), "prefix", assertions);
        assertions = check(firstScenario.length() == 7, "width", assertions);
        assertions = check(!firstScenario.isBlank(), "not blank", assertions);
        assertions = check(firstScenario != secondScenario, "distinct strings", assertions);
        assertions = check("WO-0001".equals(firstScenario), "replay", assertions);
        System.out.println("exercise.assertions=" + assertions + " passed");
    }

    private static int check(boolean condition, String message, int assertions) {
        if (!condition) {
            throw new AssertionError(message);
        }
        return assertions + 1;
    }
}
