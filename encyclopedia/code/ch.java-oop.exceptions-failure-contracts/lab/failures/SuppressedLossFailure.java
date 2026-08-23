public final class SuppressedLossFailure {
    private SuppressedLossFailure() {
    }

    static final class BrokenScope implements AutoCloseable {
        @Override
        public void close() throws Exception {
            throw new Exception("close failed");
        }
    }

    static void brokenOperation() {
        BrokenScope scope = new BrokenScope();
        try {
            throw new IllegalStateException("operation failed");
        } finally {
            try {
                scope.close();
            } catch (Exception ignoredCloseFailure) {
                // Intentional teaching bug: close failure is discarded instead of suppressed.
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
                System.exit(8);
            }
            throw new AssertionError("fixture unexpectedly retained the close failure");
        }
    }
}
