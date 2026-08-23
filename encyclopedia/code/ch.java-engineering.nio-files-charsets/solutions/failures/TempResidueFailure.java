import java.nio.file.Files;
import java.nio.file.Path;
import java.util.Comparator;
import java.util.stream.Stream;

public final class TempResidueFailure {
    private TempResidueFailure() {
    }

    public static void main(String[] args) throws Exception {
        Path root = Files.createTempDirectory("solution-residue-");
        long residues;
        try {
            Files.writeString(root.resolve("target.txt"), "old");
            Files.writeString(Files.createTempFile(root, ".solution-", ".tmp"), "partial");
            try (Stream<Path> paths = Files.list(root)) {
                residues = paths.filter(path -> path.getFileName().toString().startsWith(".solution-")).count();
            }
        } finally {
            try (Stream<Path> paths = Files.walk(root)) {
                for (Path path : paths.sorted(Comparator.reverseOrder()).toList()) {
                    Files.delete(path);
                }
            }
        }
        if (residues == 1) {
            System.err.println("TEMP_RESIDUE_AFTER_FAILURE count=1");
            System.exit(8);
        }
        throw new AssertionError("fixture residue count changed: " + residues);
    }
}
