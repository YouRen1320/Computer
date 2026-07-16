public final class GlobalCounterOrderFailure {
    private static int next = 1;

    private GlobalCounterOrderFailure() {
    }

    private static String nextId() {
        return "WO-%04d".formatted(next++);
    }

    public static void main(String[] args) {
        String firstScenario = nextId();
        if (!"WO-0001".equals(firstScenario)) {
            throw new AssertionError("unexpected first scenario");
        }

        String secondScenario = nextId();
        if (!"WO-0001".equals(secondScenario)) {
            System.err.println("ORDER_DEPENDENCY expected=WO-0001 actual=" + secondScenario);
            System.exit(1);
        }
    }
}
