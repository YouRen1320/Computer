import java.io.ByteArrayInputStream;
import java.io.IOException;

public final class UnclosedStreamFailure {
    private UnclosedStreamFailure() {
    }

    static final class Probe extends ByteArrayInputStream {
        private boolean closed;

        Probe() {
            super(new byte[] {1});
        }

        @Override
        public void close() throws IOException {
            closed = true;
            super.close();
        }
    }

    public static void main(String[] args) throws Exception {
        Probe probe = new Probe();
        probe.read();
        if (!probe.closed) {
            System.err.println("STREAM_LEAK owner=missing closed=false");
            System.exit(6);
        }
        throw new AssertionError("fixture unexpectedly closed stream");
    }
}
