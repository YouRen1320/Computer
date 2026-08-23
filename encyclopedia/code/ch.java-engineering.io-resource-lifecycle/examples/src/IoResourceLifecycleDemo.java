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
import java.util.Arrays;

public final class IoResourceLifecycleDemo {
    private IoResourceLifecycleDemo() {
    }

    static final class TrackingInputStream extends ByteArrayInputStream {
        private boolean closed;

        TrackingInputStream(byte[] data) {
            super(data);
        }

        @Override
        public void close() throws IOException {
            closed = true;
            super.close();
        }

        boolean closed() {
            return closed;
        }
    }

    static final class TrackingOutputStream extends ByteArrayOutputStream {
        private boolean closed;

        @Override
        public void close() throws IOException {
            closed = true;
            super.close();
        }

        boolean closed() {
            return closed;
        }
    }

    static final class TrackingReader extends StringReader {
        private boolean closed;

        TrackingReader(String text) {
            super(text);
        }

        @Override
        public void close() {
            closed = true;
            super.close();
        }

        boolean closed() {
            return closed;
        }
    }

    static final class TrackingWriter extends StringWriter {
        private boolean closed;

        @Override
        public void close() throws IOException {
            closed = true;
            super.close();
        }

        boolean closed() {
            return closed;
        }
    }

    static final class ExplodingReader extends Reader {
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

    static final class ExplodingWriter extends Writer {
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

    static final class TextCopyException extends RuntimeException {
        TextCopyException(String message, Throwable cause) {
            super(message, cause);
        }
    }

    static void copyUtf8Owned(InputStream input, OutputStream output) throws IOException {
        try (Reader reader = new BufferedReader(new InputStreamReader(input, StandardCharsets.UTF_8));
                Writer writer = new BufferedWriter(new OutputStreamWriter(output, StandardCharsets.UTF_8))) {
            copyBorrowed(reader, writer);
        }
    }

    static long copyBorrowed(Reader reader, Writer writer) throws IOException {
        char[] buffer = new char[5];
        long count = 0;
        int read;
        while ((read = reader.read(buffer)) != -1) {
            writer.write(buffer, 0, read);
            count += read;
        }
        return count;
    }

    static long copyBinaryBorrowed(InputStream input, OutputStream output) throws IOException {
        byte[] buffer = new byte[3];
        long count = 0;
        int read;
        while ((read = input.read(buffer)) != -1) {
            output.write(buffer, 0, read);
            count += read;
        }
        return count;
    }

    static void copyFailingOwned(Reader reader, Writer writer) {
        try (reader; writer) {
            copyBorrowed(reader, writer);
        } catch (IOException cause) {
            throw new TextCopyException("UTF-8 text copy failed", cause);
        }
    }

    public static void main(String[] args) throws Exception {
        int assertions = 0;
        String text = "设备=A-17\n状态=运行\n🚧";
        TrackingInputStream normalInput = new TrackingInputStream(text.getBytes(StandardCharsets.UTF_8));
        TrackingOutputStream normalOutput = new TrackingOutputStream();
        copyUtf8Owned(normalInput, normalOutput);
        String copied = normalOutput.toString(StandardCharsets.UTF_8);
        assertions = check(text.equals(copied), "UTF-8 round trip", assertions);
        assertions = check(normalInput.closed(), "owned input closed", assertions);
        assertions = check(normalOutput.closed(), "owned output closed", assertions);
        assertions = check(normalOutput.size() > text.length(), "UTF-8 bytes differ from char count", assertions);

        TrackingInputStream emptyInput = new TrackingInputStream(new byte[0]);
        TrackingOutputStream emptyOutput = new TrackingOutputStream();
        copyUtf8Owned(emptyInput, emptyOutput);
        assertions = check(emptyOutput.size() == 0, "empty copy", assertions);
        assertions = check(emptyInput.closed(), "empty input closed", assertions);
        assertions = check(emptyOutput.closed(), "empty output closed", assertions);

        byte[] binary = {(byte) 0x00, (byte) 0xff, (byte) 0x10, (byte) 0x20};
        ByteArrayOutputStream binaryOutput = new ByteArrayOutputStream();
        copyBinaryBorrowed(new ByteArrayInputStream(binary), binaryOutput);
        assertions = check(Arrays.equals(binary, binaryOutput.toByteArray()), "binary bytes preserved", assertions);

        TrackingReader borrowedReader = new TrackingReader("borrowed-data");
        TrackingWriter borrowedWriter = new TrackingWriter();
        long borrowedCount = copyBorrowed(borrowedReader, borrowedWriter);
        assertions = check("borrowed-data".equals(borrowedWriter.toString()), "borrowed copy", assertions);
        assertions = check(!borrowedReader.closed(), "borrowed reader remains open", assertions);
        assertions = check(!borrowedWriter.closed(), "borrowed writer remains open", assertions);

        ExplodingReader explodingReader = new ExplodingReader();
        ExplodingWriter explodingWriter = new ExplodingWriter();
        IOException primary = null;
        try {
            copyFailingOwned(explodingReader, explodingWriter);
            throw new AssertionError("failure fixture must throw");
        } catch (TextCopyException failure) {
            assertions = check(failure.getCause() instanceof IOException, "cause retained", assertions);
            primary = (IOException) failure.getCause();
        }
        assertions = check(primary != null && "read failed".equals(primary.getMessage()), "read remains primary", assertions);
        assertions = check(primary != null && primary.getSuppressed().length == 2, "two close failures suppressed", assertions);
        assertions = check(primary != null && "output close failed".equals(primary.getSuppressed()[0].getMessage()),
                "output closes first", assertions);
        assertions = check(primary != null && "input close failed".equals(primary.getSuppressed()[1].getMessage()),
                "input closes second", assertions);
        assertions = check(explodingReader.closed, "failing reader closed", assertions);
        assertions = check(explodingWriter.closed, "failing writer closed", assertions);

        System.out.println("text.roundTrip=" + text.equals(copied));
        System.out.println("text.containsChinese=" + copied.contains("设备=A-17"));
        System.out.println("text.closed=input:" + normalInput.closed() + ",output:" + normalOutput.closed());
        System.out.println("empty.bytes=" + emptyOutput.size());
        System.out.println("binary.hex=" + hex(binaryOutput.toByteArray()));
        System.out.println("borrowed.count=" + borrowedCount);
        System.out.println("borrowed.closed=reader:" + borrowedReader.closed() + ",writer:" + borrowedWriter.closed());
        System.out.println("suppressed.primary=" + primary.getMessage());
        System.out.println("suppressed.count=" + primary.getSuppressed().length);
        System.out.println("suppressed.order=" + primary.getSuppressed()[0].getMessage() + ","
                + primary.getSuppressed()[1].getMessage());
        System.out.println("assertions=" + assertions + " passed");
    }

    private static String hex(byte[] bytes) {
        StringBuilder result = new StringBuilder();
        for (byte value : bytes) {
            result.append(String.format("%02x", value & 0xff));
        }
        return result.toString();
    }

    private static int check(boolean condition, String message, int assertions) {
        if (!condition) {
            throw new AssertionError(message);
        }
        return assertions + 1;
    }
}
