import java.nio.charset.Charset;
import java.nio.charset.StandardCharsets;

public final class DefaultCharsetFailure {
    private DefaultCharsetFailure() {
    }

    public static void main(String[] args) {
        String original = "设备状态";
        byte[] utf8 = original.getBytes(StandardCharsets.UTF_8);
        String decoded = new String(utf8);
        if (!original.equals(decoded)) {
            System.err.println("DEFAULT_CHARSET_MISMATCH charset=" + Charset.defaultCharset().name()
                    + " roundTrip=false");
            System.exit(4);
        }
        throw new AssertionError("fixture default charset unexpectedly matched UTF-8");
    }
}
