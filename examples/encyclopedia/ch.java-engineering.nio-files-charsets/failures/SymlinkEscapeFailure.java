import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.FileVisitResult;
import java.nio.file.Files;
import java.nio.file.LinkOption;
import java.nio.file.Path;
import java.nio.file.SimpleFileVisitor;
import java.nio.file.attribute.BasicFileAttributes;

public final class SymlinkEscapeFailure {
    private SymlinkEscapeFailure() {
    }

    public static void main(String[] args) throws Exception {
        Path root = Files.createTempDirectory("symlink-escape-");
        boolean lexicalInside;
        boolean realInside;
        try {
            Path base = Files.createDirectory(root.resolve("allowed"));
            Path outside = Files.createDirectory(root.resolve("outside"));
            Files.writeString(outside.resolve("secret.txt"), "SECRET", StandardCharsets.UTF_8);
            Files.createSymbolicLink(base.resolve("link"), outside);
            Path candidate = base.resolve("link/secret.txt").normalize();
            lexicalInside = candidate.startsWith(base.normalize());
            realInside = candidate.toRealPath().startsWith(base.toRealPath());
        } finally {
            if (Files.exists(root, LinkOption.NOFOLLOW_LINKS)) {
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
        if (lexicalInside && !realInside) {
            System.err.println("SYMLINK_ESCAPE lexicalInside=true realInside=false");
            System.exit(7);
        }
        throw new AssertionError("fixture did not escape through symlink");
    }
}
