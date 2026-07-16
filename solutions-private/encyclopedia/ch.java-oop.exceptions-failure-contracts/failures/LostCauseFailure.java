public final class LostCauseFailure {
    private LostCauseFailure() {
    }

    static final class CreationException extends RuntimeException {
        CreationException(String message) {
            super(message);
        }
    }

    public static void main(String[] args) {
        try {
            try {
                throw new Exception("gateway unavailable");
            } catch (Exception ignoredCause) {
                throw new CreationException("create failed");
            }
        } catch (CreationException failure) {
            if (failure.getCause() == null) {
                System.err.println("CAUSE_LOST outer=CreationException cause=null");
                System.exit(5);
            }
            throw new AssertionError("fixture unexpectedly preserved cause");
        }
    }
}
