public final class FinallyReturnFailure {
    private FinallyReturnFailure() {
    }

    static String brokenOperation() {
        try {
            throw new IllegalStateException("operation failed");
        } finally {
            return "SUCCESS";
        }
    }

    public static void main(String[] args) {
        String actual = brokenOperation();
        if ("SUCCESS".equals(actual)) {
            System.err.println("FINALLY_RETURN_SWALLOWED actual=SUCCESS original=IllegalStateException");
            System.exit(7);
        }
        throw new AssertionError("fixture did not swallow the failure");
    }
}
