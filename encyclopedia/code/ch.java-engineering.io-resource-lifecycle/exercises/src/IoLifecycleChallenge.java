import java.io.BufferedReader;
import java.io.BufferedWriter;
import java.io.ByteArrayInputStream;
import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.io.OutputStream;
import java.io.OutputStreamWriter;
import java.io.Reader;
import java.io.Writer;
import java.nio.charset.StandardCharsets;

public final class IoLifecycleChallenge {
    private IoLifecycleChallenge() {
    }

    static final class CopyException extends RuntimeException {
        CopyException(String message, Throwable cause) {
            super(message, cause);
        }
    }

    static final class ProbeInput extends ByteArrayInputStream {
        private boolean closed;

        ProbeInput(byte[] data) {
            super(data);
        }

        @Override
        public void close() throws IOException {
            closed = true;
            super.close();
        }
    }

    static final class ProbeOutput extends ByteArrayOutputStream {
        private boolean closed;

        @Override
        public void close() throws IOException {
            closed = true;
            super.close();
        }
    }

    static final class FailingInput extends InputStream {
        private boolean closed;

        @Override
        public int read() throws IOException {
            throw new IOException("read failed");
        }

        @Override
        public void close() throws IOException {
            closed = true;
            throw new IOException("input close failed");
        }
    }

    static final class FailingOutput extends OutputStream {
        private boolean closed;

        @Override
        public void write(int value) {
        }

        @Override
        public void close() throws IOException {
            closed = true;
            throw new IOException("output close failed");
        }
    }

    static String brokenCopyUtf8Owned(InputStream input, OutputStream output) {
        try {
            Reader reader = new BufferedReader(new InputStreamReader(input, StandardCharsets.UTF_8));
            Writer writer = new BufferedWriter(new OutputStreamWriter(output, StandardCharsets.UTF_8));
            char[] buffer = new char[4];
            StringBuilder result = new StringBuilder();
            int read;
            while ((read = reader.read(buffer)) != -1) {
                writer.write(buffer, 0, read);
                result.append(buffer, 0, read);
            }
            writer.flush();
            // TODO：由拥有边界确定关闭，并让失败带 cause 传播。
            return result.toString();
        } catch (IOException ignored) {
            return "";
        }
    }

    public static void main(String[] args) {
        FailingInput failingInput = new FailingInput();
        FailingOutput failingOutput = new FailingOutput();
        CopyException observedFailure = null;
        String swallowedResult = null;
        try {
            swallowedResult = brokenCopyUtf8Owned(failingInput, failingOutput);
        } catch (CopyException expected) {
            observedFailure = expected;
        }
        if (observedFailure == null) {
            System.err.println("STARTER_SWALLOWED_IO expected=CopyException actual="
                    + (swallowedResult == null || swallowedResult.isEmpty() ? "empty-text" : "returned-text"));
            System.exit(8);
        }

        String text = "设备状态=运行";
        ProbeInput normalInput = new ProbeInput(text.getBytes(StandardCharsets.UTF_8));
        ProbeOutput normalOutput = new ProbeOutput();
        String copied = brokenCopyUtf8Owned(normalInput, normalOutput);
        ProbeInput emptyInput = new ProbeInput(new byte[0]);
        ProbeOutput emptyOutput = new ProbeOutput();
        String emptyCopied = brokenCopyUtf8Owned(emptyInput, emptyOutput);
        if (!normalInput.closed || !normalOutput.closed) {
            System.err.println("STARTER_STREAM_LEAK inputClosed=" + normalInput.closed
                    + " outputClosed=" + normalOutput.closed);
            System.exit(9);
        }

        int assertions = 0;
        assertions = check(text.equals(copied), "text copied", assertions);
        assertions = check(text.equals(normalOutput.toString(StandardCharsets.UTF_8)), "UTF-8 output", assertions);
        assertions = check(normalInput.closed, "input closed", assertions);
        assertions = check(normalOutput.closed, "output closed", assertions);
        assertions = check(failingInput.closed, "failing input closed", assertions);
        assertions = check(failingOutput.closed, "failing output closed", assertions);
        Throwable cause = observedFailure.getCause();
        assertions = check(cause instanceof IOException, "cause retained", assertions);
        assertions = check(cause != null && cause.getSuppressed().length == 2, "suppressed retained", assertions);
        assertions = check(cause != null && "output close failed".equals(cause.getSuppressed()[0].getMessage()),
                "output closes first", assertions);
        assertions = check(cause != null && "input close failed".equals(cause.getSuppressed()[1].getMessage()),
                "input closes second", assertions);
        assertions = check(StandardCharsets.UTF_8 != null, "explicit charset", assertions);
        assertions = check(copied.length() == text.length(), "character count", assertions);
        assertions = check(normalOutput.size() > copied.length(), "byte count", assertions);
        assertions = check(emptyCopied.isEmpty() && emptyOutput.size() == 0, "empty input", assertions);
        assertions = check(emptyInput.closed, "empty input closed", assertions);
        assertions = check(emptyOutput.closed, "empty output closed", assertions);
        System.out.println("challenge.assertions=" + assertions + " passed");
    }

    private static int check(boolean condition, String message, int assertions) {
        if (!condition) {
            throw new AssertionError(message);
        }
        return assertions + 1;
    }
}
