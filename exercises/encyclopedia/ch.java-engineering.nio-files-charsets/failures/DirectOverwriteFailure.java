import java.io.IOException;
import java.io.Writer;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardOpenOption;
import java.util.stream.Stream;

public final class DirectOverwriteFailure {
    private DirectOverwriteFailure() {
    }

    public static void main(String[] args) throws Exception {
        Path root = Files.createTempDirectory("exercise-overwrite-");
        boolean partial;
        try {
            Path target = root.resolve("target.txt");
            Files.writeString(target, "old-complete", StandardCharsets.UTF_8);
            try (Writer output = Files.newBufferedWriter(target, StandardCharsets.UTF_8,
                    StandardOpenOption.TRUNCATE_EXISTING)) {
                output.write("new-");
                throw new IOException("injected interruption");
            } catch (IOException expected) {
                // Observe the damaged target.
            }
            partial = "new-".equals(Files.readString(target, StandardCharsets.UTF_8));
        } finally {
            try (Stream<Path> paths = Files.list(root)) {
                for (Path path : paths.toList()) {
                    Files.delete(path);
                }
            }
            Files.delete(root);
        }
        if (partial) {
            System.err.println("DIRECT_OVERWRITE_PARTIAL expected=old-complete actual=new-");
            System.exit(4);
        }
        throw new AssertionError("fixture did not produce partial target");
    }
}
