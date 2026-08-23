import java.nio.file.Files;
import java.nio.file.Path;

public final class RelativeBaseFailure {
    private RelativeBaseFailure() {
    }

    public static void main(String[] args) throws Exception {
        Path expectedBase = Files.createTempDirectory("exercise-base-").toAbsolutePath().normalize();
        boolean drift;
        try {
            drift = !Path.of("config.txt").toAbsolutePath().normalize().startsWith(expectedBase);
        } finally {
            Files.delete(expectedBase);
        }
        if (drift) {
            System.err.println("RELATIVE_BASE_DRIFT expectedConfiguredBase=true actualConfiguredBase=false");
            System.exit(5);
        }
        throw new AssertionError("fixture unexpectedly selected configured base");
    }
}
