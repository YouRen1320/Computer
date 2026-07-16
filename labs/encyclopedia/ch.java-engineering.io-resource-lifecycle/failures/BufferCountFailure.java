import java.io.ByteArrayInputStream;
import java.io.ByteArrayOutputStream;

public final class BufferCountFailure {
    private BufferCountFailure() {
    }

    public static void main(String[] args) throws Exception {
        ByteArrayInputStream input = new ByteArrayInputStream(new byte[] {1, 2, 3, 4, 5});
        ByteArrayOutputStream output = new ByteArrayOutputStream();
        byte[] buffer = new byte[4];
        int read;
        while ((read = input.read(buffer)) != -1) {
            output.write(buffer); // Intentional bug: ignores read.
        }
        if (output.size() == 8) {
            System.err.println("BUFFER_COUNT_IGNORED expectedLength=5 actualLength=8 hex=0102030405020304");
            System.exit(8);
        }
        throw new AssertionError("fixture did not write stale buffer bytes");
    }
}
