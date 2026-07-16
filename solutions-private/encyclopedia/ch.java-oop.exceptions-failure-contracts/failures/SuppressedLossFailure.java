public final class SuppressedLossFailure {
    private SuppressedLossFailure() {
    }

    static void brokenOperation() {
        try {
            throw new IllegalStateException("operation failed");
        } finally {
            try {
                throw new Exception("close failed");
            } catch (Exception ignoredClose) {
                // Intentional fault fixture.
            }
        }
    }

    public static void main(String[] args) {
        try {
            brokenOperation();
            throw new AssertionError("fixture did not throw");
        } catch (IllegalStateException failure) {
            if (failure.getSuppressed().length == 0) {
                System.err.println("SUPPRESSED_LOST primary=operation-failed suppressed=0");
                System.exit(7);
            }
            throw new AssertionError("fixture unexpectedly retained close failure");
        }
    }
}
