import java.io.IOException;

public final class SwallowedIoFailure {
    private SwallowedIoFailure() {
    }

    static String brokenRead() {
        try {
            throw new IOException("read failed");
        } catch (IOException ignored) {
            return "";
        }
    }

    public static void main(String[] args) {
        if (brokenRead().isEmpty()) {
            System.err.println("SWALLOWED_IO expected=failure actual=empty-text");
            System.exit(4);
        }
        throw new AssertionError("fixture did not swallow I/O failure");
    }
}
