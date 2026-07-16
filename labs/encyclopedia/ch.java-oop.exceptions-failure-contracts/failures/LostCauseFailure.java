public final class LostCauseFailure {
    private LostCauseFailure() {
    }

    static final class CreationException extends RuntimeException {
        CreationException(String message) {
            super(message);
        }
    }

    static void brokenTranslate() {
        try {
            throw new Exception("gateway unavailable");
        } catch (Exception ignoredCause) {
            throw new CreationException("create failed");
        }
    }

    public static void main(String[] args) {
        try {
            brokenTranslate();
            throw new AssertionError("fixture did not throw");
        } catch (CreationException failure) {
            if (failure.getCause() == null) {
                System.err.println("CAUSE_LOST outer=CreationException cause=null");
                System.exit(5);
            }
            throw new AssertionError("fixture unexpectedly preserved cause");
        }
    }
}
