import java.io.IOException;
import java.nio.file.FileVisitResult;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.SimpleFileVisitor;
import java.nio.file.attribute.BasicFileAttributes;
import java.util.stream.Stream;

public final class TempResidueFailure {
    private TempResidueFailure() {
    }

    public static void main(String[] args) throws Exception {
        Path root = Files.createTempDirectory("lab-temp-residue-");
        long residues;
        try {
            Path target = root.resolve("config.txt");
            Files.writeString(target, "old");
            Path temp = Files.createTempFile(root, ".lab-", ".tmp");
            Files.writeString(temp, "partial");
            try (Stream<Path> paths = Files.list(root)) {
                residues = paths.filter(path -> path.getFileName().toString().startsWith(".lab-")).count();
            }
        } finally {
            deleteTree(root);
        }
        if (residues == 1) {
            System.err.println("TEMP_RESIDUE_AFTER_FAILURE count=1");
            System.exit(8);
        }
        throw new AssertionError("fixture residue count changed: " + residues);
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
