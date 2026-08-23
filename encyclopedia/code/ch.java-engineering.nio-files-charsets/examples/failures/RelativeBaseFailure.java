import java.io.IOException;
import java.nio.file.FileVisitResult;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.SimpleFileVisitor;
import java.nio.file.attribute.BasicFileAttributes;

public final class RelativeBaseFailure {
    private RelativeBaseFailure() {
    }

    public static void main(String[] args) throws Exception {
        Path expectedBase = Files.createTempDirectory("configured-base-").toAbsolutePath().normalize();
        boolean drift;
        try {
            Path actual = Path.of("config.txt").toAbsolutePath().normalize();
            drift = !actual.startsWith(expectedBase);
        } finally {
            Files.walkFileTree(expectedBase, new SimpleFileVisitor<>() {
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
        if (drift) {
            System.err.println("RELATIVE_BASE_DRIFT expectedConfiguredBase=true actualConfiguredBase=false");
            System.exit(6);
        }
        throw new AssertionError("fixture unexpectedly used the configured base");
    }
}
