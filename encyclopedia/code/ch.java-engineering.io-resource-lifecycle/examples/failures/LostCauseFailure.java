import java.io.IOException;

public final class LostCauseFailure {
    private LostCauseFailure() {
    }

    static final class CopyException extends RuntimeException {
        CopyException(String message) {
            super(message);
        }
    }

    static void brokenCopy() {
        try {
            throw new IOException("read failed");
        } catch (IOException ignoredCause) {
            throw new CopyException("copy failed");
        }
    }

    public static void main(String[] args) {
        try {
            brokenCopy();
            throw new AssertionError("fixture did not throw");
        } catch (CopyException failure) {
            if (failure.getCause() == null) {
                System.err.println("IO_CAUSE_LOST outer=CopyException cause=null");
                System.exit(5);
            }
            throw new AssertionError("fixture unexpectedly preserved cause");
        }
    }
}
