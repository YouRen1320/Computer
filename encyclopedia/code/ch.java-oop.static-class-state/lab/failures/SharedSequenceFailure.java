public final class SharedSequenceFailure {
    private static int next = 1;

    private SharedSequenceFailure() {
    }

    private static String nextId() {
        return "NC-%04d".formatted(next++);
    }

    public static void main(String[] args) {
        String firstTest = nextId();
        if (!"NC-0001".equals(firstTest)) {
            throw new AssertionError("first test setup failed");
        }
        String secondTest = nextId();
        if (!"NC-0001".equals(secondTest)) {
            System.err.println("SHARED_SEQUENCE expected=NC-0001 actual=" + secondTest);
            System.exit(1);
        }
    }
}
