import java.io.IOException;

public final class CloseOverridesReadFailure {
    private CloseOverridesReadFailure() {
    }

    static void brokenOperation() throws IOException {
        try {
            throw new IOException("read failed");
        } finally {
            throw new IOException("close failed");
        }
    }

    public static void main(String[] args) {
        try {
            brokenOperation();
            throw new AssertionError("fixture did not throw");
        } catch (IOException failure) {
            if ("close failed".equals(failure.getMessage()) && failure.getSuppressed().length == 0) {
                System.err.println("PRIMARY_OVERRIDDEN actual=close-failed original=read-failed suppressed=0");
                System.exit(7);
            }
            throw new AssertionError("fixture did not override the primary failure");
        }
    }
}
