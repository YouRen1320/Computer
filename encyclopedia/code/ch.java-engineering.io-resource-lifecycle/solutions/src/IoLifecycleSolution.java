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
import java.io.StringReader;
import java.io.StringWriter;
import java.io.Writer;
import java.nio.charset.StandardCharsets;

public final class IoLifecycleSolution {
    private IoLifecycleSolution() {
    }

    static final class ProbeInput extends ByteArrayInputStream {
        private boolean closed;

        ProbeInput(byte[] bytes) {
            super(bytes);
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

    static final class ProbeReader extends StringReader {
        private boolean closed;

        ProbeReader(String text) {
            super(text);
        }

        @Override
        public void close() {
            closed = true;
            super.close();
        }
    }

    static final class ProbeWriter extends StringWriter {
        private boolean closed;

        @Override
        public void close() throws IOException {
            closed = true;
            super.close();
        }
    }

    static final class FailingReader extends Reader {
        private boolean closed;

        @Override
        public int read(char[] buffer, int offset, int length) throws IOException {
            throw new IOException("read failed");
        }

        @Override
        public void close() throws IOException {
            closed = true;
            throw new IOException("input close failed");
        }
    }

    static final class FailingWriter extends Writer {
        private boolean closed;

        @Override
        public void write(char[] buffer, int offset, int length) {
        }

        @Override
        public void flush() {
        }

        @Override
        public void close() throws IOException {
            closed = true;
            throw new IOException("output close failed");
        }
    }

    static final class CopyException extends RuntimeException {
        CopyException(String message, Throwable cause) {
            super(message, cause);
        }
    }

    static long copyUtf8Owned(InputStream input, OutputStream output) {
        try (Reader reader = new BufferedReader(new InputStreamReader(input, StandardCharsets.UTF_8));
                Writer writer = new BufferedWriter(new OutputStreamWriter(output, StandardCharsets.UTF_8))) {
            return copyBorrowed(reader, writer);
        } catch (IOException cause) {
            throw new CopyException("UTF-8 copy failed", cause);
        }
    }

    static long copyBorrowed(Reader reader, Writer writer) throws IOException {
        char[] buffer = new char[4];
        long count = 0;
        int read;
        while ((read = reader.read(buffer)) != -1) {
            writer.write(buffer, 0, read);
            count += read;
        }
        return count;
    }

    static void failingOwned(Reader reader, Writer writer) {
        try (reader; writer) {
            copyBorrowed(reader, writer);
        } catch (IOException cause) {
            throw new CopyException("UTF-8 copy failed", cause);
        }
    }

    public static void main(String[] args) throws Exception {
        int assertions = 0;
        String text = "设备=A-17\n状态=运行\n";
        ProbeInput input = new ProbeInput(text.getBytes(StandardCharsets.UTF_8));
        ProbeOutput output = new ProbeOutput();
        long count = copyUtf8Owned(input, output);
        String copied = output.toString(StandardCharsets.UTF_8);
        assertions = check(text.equals(copied), "round trip", assertions);
        assertions = check(count == text.length(), "character count", assertions);
        assertions = check(input.closed, "input closed", assertions);
        assertions = check(output.closed, "output closed", assertions);

        ProbeInput emptyInput = new ProbeInput(new byte[0]);
        ProbeOutput emptyOutput = new ProbeOutput();
        copyUtf8Owned(emptyInput, emptyOutput);
        assertions = check(emptyOutput.size() == 0, "empty output", assertions);
        assertions = check(emptyInput.closed, "empty input closed", assertions);
        assertions = check(emptyOutput.closed, "empty output closed", assertions);

        ProbeReader borrowedReader = new ProbeReader("borrowed");
        ProbeWriter borrowedWriter = new ProbeWriter();
        copyBorrowed(borrowedReader, borrowedWriter);
        assertions = check("borrowed".equals(borrowedWriter.toString()), "borrowed copy", assertions);
        assertions = check(!borrowedReader.closed, "borrowed reader open", assertions);
        assertions = check(!borrowedWriter.closed, "borrowed writer open", assertions);

        FailingReader failingReader = new FailingReader();
        FailingWriter failingWriter = new FailingWriter();
        IOException primary = null;
        try {
            failingOwned(failingReader, failingWriter);
        } catch (CopyException failure) {
            assertions = check(failure.getCause() instanceof IOException, "cause retained", assertions);
            primary = (IOException) failure.getCause();
        }
        assertions = check(primary != null && "read failed".equals(primary.getMessage()), "primary", assertions);
        assertions = check(primary != null && primary.getSuppressed().length == 2, "suppressed count", assertions);
        assertions = check(primary != null && "output close failed".equals(primary.getSuppressed()[0].getMessage()),
                "output close first", assertions);
        assertions = check(failingReader.closed, "failing reader closed", assertions);
        assertions = check(failingWriter.closed, "failing writer closed", assertions);

        System.out.println("solution.text.roundTrip=" + text.equals(copied));
        System.out.println("solution.closed=input:" + input.closed + ",output:" + output.closed);
        System.out.println("solution.empty=" + emptyOutput.size());
        System.out.println("solution.borrowed.closed=reader:" + borrowedReader.closed + ",writer:" + borrowedWriter.closed);
        System.out.println("solution.suppressed=" + primary.getSuppressed().length);
        System.out.println("solution.assertions=" + assertions + " passed");
    }

    private static int check(boolean condition, String message, int assertions) {
        if (!condition) {
            throw new AssertionError(message);
        }
        return assertions + 1;
    }
}
