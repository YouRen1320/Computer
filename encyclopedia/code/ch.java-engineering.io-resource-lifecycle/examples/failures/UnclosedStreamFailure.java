import java.io.ByteArrayInputStream;
import java.io.IOException;

public final class UnclosedStreamFailure {
    private UnclosedStreamFailure() {
    }

    static final class ProbeInput extends ByteArrayInputStream {
        private boolean closed;

        ProbeInput() {
            super(new byte[] {1, 2, 3});
        }

        @Override
        public void close() throws IOException {
            closed = true;
            super.close();
        }
    }

    public static void main(String[] args) throws Exception {
        ProbeInput input = new ProbeInput();
        while (input.read() != -1) {
            // Intentional leak: no owner closes the stream.
        }
        if (!input.closed) {
            System.err.println("STREAM_LEAK owner=missing closed=false");
            System.exit(6);
        }
        throw new AssertionError("fixture unexpectedly closed the stream");
    }
}
