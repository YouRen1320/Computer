import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.FileVisitOption;
import java.nio.file.FileVisitResult;
import java.nio.file.Files;
import java.nio.file.LinkOption;
import java.nio.file.Path;
import java.nio.file.SimpleFileVisitor;
import java.nio.file.attribute.BasicFileAttributes;
import java.util.stream.Stream;

public final class FollowLinksEscapeFailure {
    private FollowLinksEscapeFailure() {
    }

    public static void main(String[] args) throws Exception {
        Path root = Files.createTempDirectory("lab-follow-links-");
        boolean secretVisited;
        try {
            Path allowed = Files.createDirectory(root.resolve("allowed"));
            Path outside = Files.createDirectory(root.resolve("outside"));
            Files.writeString(outside.resolve("secret.txt"), "secret", StandardCharsets.UTF_8);
            Files.createSymbolicLink(allowed.resolve("external"), outside);
            try (Stream<Path> paths = Files.walk(allowed, 4, FileVisitOption.FOLLOW_LINKS)) {
                secretVisited = paths.anyMatch(path -> path.getFileName().toString().equals("secret.txt"));
            }
        } finally {
            deleteTree(root);
        }
        if (secretVisited) {
            System.err.println("FOLLOW_LINKS_ESCAPE secretVisited=true");
            System.exit(7);
        }
        throw new AssertionError("fixture did not visit external secret");
    }

    private static void deleteTree(Path root) throws IOException {
        if (!Files.exists(root, LinkOption.NOFOLLOW_LINKS)) {
            return;
        }
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
