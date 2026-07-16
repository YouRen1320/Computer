import java.io.IOException;
import java.nio.file.Path;

public final class MissingFileFailure {
    private MissingFileFailure() {
    }

    public static void main(String[] args) {
        try {
            JsonSupport.JsonFiles.readUtf8(Path.of(args[0]));
        } catch (IOException expected) {
            throw new IllegalStateException("IO_READ_FAILURE", expected);
        }
        throw new AssertionError("IO_READ_FAILURE was not raised");
    }
}
