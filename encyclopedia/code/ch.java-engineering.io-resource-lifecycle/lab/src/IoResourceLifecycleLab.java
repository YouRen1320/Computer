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
import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;

public final class IoResourceLifecycleLab {
    private IoResourceLifecycleLab() {
    }

    static final class ProbeInput extends InputStream {
        private final ByteArrayInputStream delegate;
        private final int maxChunk;
        private boolean closed;

        ProbeInput(byte[] data, int maxChunk) {
            delegate = new ByteArrayInputStream(data);
            this.maxChunk = maxChunk;
        }

        @Override
        public int read() {
            return delegate.read();
        }

        @Override
        public int read(byte[] buffer, int offset, int length) {
            return delegate.read(buffer, offset, Math.min(length, maxChunk));
        }

        @Override
        public void close() throws IOException {
            closed = true;
            delegate.close();
        }
    }

    static final class ProbeOutput extends OutputStream {
        private final ByteArrayOutputStream delegate = new ByteArrayOutputStream();
        private boolean closed;

        @Override
        public void write(int value) {
            delegate.write(value);
        }

        @Override
        public void write(byte[] buffer, int offset, int length) {
            delegate.write(buffer, offset, length);
        }

        @Override
        public void close() throws IOException {
            closed = true;
            delegate.close();
        }

        byte[] bytes() {
            return delegate.toByteArray();
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

    static final class Stage implements AutoCloseable {
        private final String name;
        private final List<String> events;
        private boolean closed;

        Stage(String name, List<String> events) {
            this.name = name;
            this.events = events;
            events.add("open:" + name);
        }

        @Override
        public void close() {
            closed = true;
            events.add("close:" + name);
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

    static long copyUtf8Owned(InputStream input, OutputStream output, long maxChars) throws IOException {
        try (Reader reader = new BufferedReader(new InputStreamReader(input, StandardCharsets.UTF_8));
                Writer writer = new BufferedWriter(new OutputStreamWriter(output, StandardCharsets.UTF_8))) {
            char[] buffer = new char[3];
            long count = 0;
            int read;
            while ((read = reader.read(buffer)) != -1) {
                if (count + read > maxChars) {
                    throw new IOException("character limit exceeded");
                }
                writer.write(buffer, 0, read);
                count += read;
            }
            return count;
        }
    }

    static void copyBorrowed(Reader reader, Writer writer) throws IOException {
        char[] buffer = new char[4];
        int read;
        while ((read = reader.read(buffer)) != -1) {
            writer.write(buffer, 0, read);
        }
    }

    static void failingOwned(Reader reader, Writer writer) throws IOException {
        try (reader; writer) {
            copyBorrowed(reader, writer);
        }
    }

    static Stage failSecondResource() throws IOException {
        throw new IOException("second open failed");
    }

    public static void main(String[] args) throws Exception {
        int assertions = 0;
        String text = "南昌设备🚧状态正常";
        ProbeInput normalInput = new ProbeInput(text.getBytes(StandardCharsets.UTF_8), 1);
        ProbeOutput normalOutput = new ProbeOutput();
        long count = copyUtf8Owned(normalInput, normalOutput, 64);
        String copied = new String(normalOutput.bytes(), StandardCharsets.UTF_8);
        assertions = check(text.equals(copied), "one-byte chunks preserve UTF-8", assertions);
        assertions = check(normalInput.closed, "normal input closed", assertions);
        assertions = check(normalOutput.closed, "normal output closed", assertions);
        assertions = check(count == text.length(), "character count", assertions);

        ProbeInput emptyInput = new ProbeInput(new byte[0], 1);
        ProbeOutput emptyOutput = new ProbeOutput();
        copyUtf8Owned(emptyInput, emptyOutput, 64);
        assertions = check(emptyOutput.bytes().length == 0, "empty output", assertions);
        assertions = check(emptyInput.closed, "empty input closed", assertions);
        assertions = check(emptyOutput.closed, "empty output closed", assertions);

        byte[] binary = {(byte) 0x00, (byte) 0xff, (byte) 0x7f};
        ByteArrayOutputStream binaryOut = new ByteArrayOutputStream();
        new ByteArrayInputStream(binary).transferTo(binaryOut);
        assertions = check(Arrays.equals(binary, binaryOut.toByteArray()), "binary preserved", assertions);

        ProbeInput limitedInput = new ProbeInput("123456".getBytes(StandardCharsets.UTF_8), 2);
        ProbeOutput limitedOutput = new ProbeOutput();
        IOException limitFailure = null;
        try {
            copyUtf8Owned(limitedInput, limitedOutput, 5);
        } catch (IOException expected) {
            limitFailure = expected;
        }
        assertions = check(limitFailure != null && "character limit exceeded".equals(limitFailure.getMessage()),
                "limit failure", assertions);
        assertions = check(limitedInput.closed, "limited input closed", assertions);
        assertions = check(limitedOutput.closed, "limited output closed", assertions);
        assertions = check(limitedOutput.bytes().length < 6, "partial output not complete", assertions);

        ProbeReader borrowedReader = new ProbeReader("borrowed");
        ProbeWriter borrowedWriter = new ProbeWriter();
        copyBorrowed(borrowedReader, borrowedWriter);
        assertions = check("borrowed".equals(borrowedWriter.toString()), "borrowed result", assertions);
        assertions = check(!borrowedReader.closed, "borrowed reader open", assertions);
        assertions = check(!borrowedWriter.closed, "borrowed writer open", assertions);

        List<String> initEvents = new ArrayList<>();
        Stage first = new Stage("first", initEvents);
        IOException initFailure = null;
        try (first; Stage second = failSecondResource()) {
            throw new AssertionError("body must not execute");
        } catch (IOException expected) {
            initFailure = expected;
        }
        assertions = check(initFailure != null && "second open failed".equals(initFailure.getMessage()),
                "initialization failure", assertions);
        assertions = check(first.closed, "first resource closed after second init fails", assertions);
        assertions = check(initEvents.equals(List.of("open:first", "close:first")), "init event order", assertions);

        FailingReader failingReader = new FailingReader();
        FailingWriter failingWriter = new FailingWriter();
        IOException primary = null;
        try {
            failingOwned(failingReader, failingWriter);
        } catch (IOException expected) {
            primary = expected;
        }
        assertions = check(primary != null && "read failed".equals(primary.getMessage()), "primary read", assertions);
        assertions = check(primary != null && primary.getSuppressed().length == 2, "suppressed count", assertions);
        assertions = check(primary != null && "output close failed".equals(primary.getSuppressed()[0].getMessage()),
                "output close first", assertions);
        assertions = check(primary != null && "input close failed".equals(primary.getSuppressed()[1].getMessage()),
                "input close second", assertions);
        assertions = check(failingReader.closed, "failing reader closed", assertions);
        assertions = check(failingWriter.closed, "failing writer closed", assertions);

        System.out.println("report.normal=INPUT one-byte chunks | OP UTF-8 copy | RESULT roundTrip=" + text.equals(copied));
        System.out.println("report.empty=INPUT zero bytes | OP UTF-8 copy | RESULT bytes=" + emptyOutput.bytes().length);
        System.out.println("report.limit=INPUT 6 chars max=5 | OP owned copy | RESULT " + limitFailure.getMessage());
        System.out.println("resource.init=" + String.join(",", initEvents));
        System.out.println("suppressed.primary=" + primary.getMessage());
        System.out.println("suppressed.count=" + primary.getSuppressed().length);
        System.out.println("assertions=" + assertions + " passed");
    }

    private static int check(boolean condition, String message, int assertions) {
        if (!condition) {
            throw new AssertionError(message);
        }
        return assertions + 1;
    }
}
