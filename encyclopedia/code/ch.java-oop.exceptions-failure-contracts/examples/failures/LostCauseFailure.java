public final class LostCauseFailure {
    private LostCauseFailure() {
    }

    static final class GatewayAccessException extends Exception {
        GatewayAccessException(String message) {
            super(message);
        }
    }

    static final class WorkOrderCreationException extends RuntimeException {
        WorkOrderCreationException(String message) {
            super(message);
        }
    }

    static void brokenTranslate() {
        try {
            throw new GatewayAccessException("adapter unavailable");
        } catch (GatewayAccessException ignoredCause) {
            throw new WorkOrderCreationException("unable to create work order");
        }
    }

    public static void main(String[] args) {
        try {
            brokenTranslate();
            throw new AssertionError("fixture did not throw");
        } catch (WorkOrderCreationException failure) {
            if (failure.getCause() == null) {
                System.err.println("CAUSE_LOST outer=WorkOrderCreationException cause=null");
                System.exit(5);
            }
            throw new AssertionError("fixture unexpectedly preserved cause");
        }
    }
}
