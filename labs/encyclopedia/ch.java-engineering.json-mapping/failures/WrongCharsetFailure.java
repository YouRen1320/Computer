import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;

public final class WrongCharsetFailure {
    private WrongCharsetFailure() {
    }

    public static void main(String[] args) throws Exception {
        Path path = Path.of(args[0]);
        String expected = "{\"id\":\"WO-机泵-101\"}";
        Files.writeString(path, expected, StandardCharsets.UTF_8);
        String actual = Files.readString(path, StandardCharsets.ISO_8859_1);
        if (!expected.equals(actual)) {
            throw new IllegalStateException("WRONG_CHARSET expectedUtf8=true");
        }
    }
}
