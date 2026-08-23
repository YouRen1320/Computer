import java.io.IOException;

public final class SwallowedIoFailure {
    private SwallowedIoFailure() {
    }

    public static void main(String[] args) {
        String result;
        try {
            throw new IOException("read failed");
        } catch (IOException ignored) {
            result = "";
        }
        if (result.isEmpty()) {
            System.err.println("SWALLOWED_IO expected=failure actual=empty-text");
            System.exit(4);
        }
        throw new AssertionError("fixture did not swallow I/O failure");
    }
}
