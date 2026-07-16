import java.io.IOException;
import java.io.Writer;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardOpenOption;
import java.util.Comparator;

public final class DirectOverwriteFailure {
    private DirectOverwriteFailure() {
    }

    public static void main(String[] args) throws Exception {
        Path root = Files.createTempDirectory("solution-overwrite-");
        boolean partial;
        try {
            Path target = root.resolve("target.txt");
            Files.writeString(target, "old-complete", StandardCharsets.UTF_8);
            try (Writer output = Files.newBufferedWriter(target, StandardCharsets.UTF_8,
                    StandardOpenOption.TRUNCATE_EXISTING)) {
                output.write("new-");
                throw new IOException("injected interruption");
            } catch (IOException expected) {
                // Observe the state persisted by direct overwrite.
            }
            partial = "new-".equals(Files.readString(target, StandardCharsets.UTF_8));
        } finally {
            try (var paths = Files.walk(root)) {
                for (Path path : paths.sorted(Comparator.reverseOrder()).toList()) {
                    Files.delete(path);
                }
            }
        }
        if (partial) {
            System.err.println("DIRECT_OVERWRITE_PARTIAL expected=old-complete actual=new-");
            System.exit(5);
        }
        throw new AssertionError("fixture did not produce partial target");
    }
}
