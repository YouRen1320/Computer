import java.io.IOException;
import java.io.Writer;
import java.nio.charset.StandardCharsets;
import java.nio.file.FileVisitResult;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.SimpleFileVisitor;
import java.nio.file.StandardOpenOption;
import java.nio.file.attribute.BasicFileAttributes;

public final class DirectOverwriteFailure {
    private DirectOverwriteFailure() {
    }

    public static void main(String[] args) throws Exception {
        Path root = Files.createTempDirectory("lab-overwrite-");
        boolean partial;
        try {
            Path target = root.resolve("config.txt");
            Files.writeString(target, "old-complete", StandardCharsets.UTF_8);
            try (Writer writer = Files.newBufferedWriter(target, StandardCharsets.UTF_8,
                    StandardOpenOption.TRUNCATE_EXISTING)) {
                writer.write("new-");
                throw new IOException("injected interruption");
            } catch (IOException expected) {
                // The observation after failure is the evidence under test.
            }
            partial = "new-".equals(Files.readString(target, StandardCharsets.UTF_8));
        } finally {
            deleteTree(root);
        }
        if (partial) {
            System.err.println("DIRECT_OVERWRITE_PARTIAL expected=old-complete actual=new-");
            System.exit(5);
        }
        throw new AssertionError("fixture did not leave a partial target");
    }

    private static void deleteTree(Path root) throws IOException {
        Files.walkFileTree(root, new SimpleFileVisitor<>() {
            @Override
            public FileVisitResult visitFile(Path file, BasicFileAttributes attrs) throws IOException {
                Files.delete(file);
                return FileVisitResult.CONTINUE;
            }

            @Override
            public FileVisitResult postVisitDirectory(Path dir, IOException failure) throws IOException {
                Files.delete(dir);
                return FileVisitResult.CONTINUE;
            }
        });
    }
}
