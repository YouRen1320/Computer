import java.io.ByteArrayInputStream;
import java.io.ByteArrayOutputStream;

public final class BufferCountFailure {
    private BufferCountFailure() {
    }

    public static void main(String[] args) throws Exception {
        ByteArrayInputStream input = new ByteArrayInputStream(new byte[] {1, 2, 3, 4, 5});
        ByteArrayOutputStream output = new ByteArrayOutputStream();
        byte[] buffer = new byte[4];
        while (input.read(buffer) != -1) {
            output.write(buffer);
        }
        if (output.size() == 8) {
            System.err.println("BUFFER_COUNT_IGNORED expectedLength=5 actualLength=8");
            System.exit(8);
        }
        throw new AssertionError("fixture did not copy stale bytes");
    }
}
