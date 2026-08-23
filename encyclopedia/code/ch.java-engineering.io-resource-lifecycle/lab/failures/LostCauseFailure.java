import java.io.IOException;

public final class LostCauseFailure {
    private LostCauseFailure() {
    }

    static final class CopyException extends RuntimeException {
        CopyException(String message) {
            super(message);
        }
    }

    public static void main(String[] args) {
        try {
            try {
                throw new IOException("read failed");
            } catch (IOException ignored) {
                throw new CopyException("copy failed");
            }
        } catch (CopyException failure) {
            if (failure.getCause() == null) {
                System.err.println("IO_CAUSE_LOST outer=CopyException cause=null");
                System.exit(5);
            }
            throw new AssertionError("fixture unexpectedly retained cause");
        }
    }
}
