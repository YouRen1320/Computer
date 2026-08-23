import java.io.BufferedWriter;
import java.io.IOException;
import java.nio.ByteBuffer;
import java.nio.charset.CharacterCodingException;
import java.nio.charset.CodingErrorAction;
import java.nio.charset.StandardCharsets;
import java.nio.file.FileVisitResult;
import java.nio.file.Files;
import java.nio.file.LinkOption;
import java.nio.file.Path;
import java.nio.file.SimpleFileVisitor;
import java.nio.file.StandardCopyOption;
import java.nio.file.attribute.BasicFileAttributes;
import java.util.Arrays;
import java.util.List;
import java.util.stream.Stream;

public final class NioFilesCharsetsDemo {
    private NioFilesCharsetsDemo() {
    }

    @FunctionalInterface
    interface TempWriter {
        void write(Path temp) throws IOException;
    }

    static Path resolveConfined(Path base, String relative) {
        if (base == null || relative == null) {
            throw new IllegalArgumentException("base and relative path required");
        }
        Path child = Path.of(relative);
        if (child.isAbsolute()) {
            throw new IllegalArgumentException("absolute child rejected");
        }
        Path normalizedBase = base.toAbsolutePath().normalize();
        Path candidate = normalizedBase.resolve(child).normalize();
        if (candidate.equals(normalizedBase) || !candidate.startsWith(normalizedBase)) {
            throw new IllegalArgumentException("path escapes configured base");
        }
        return candidate;
    }

    static String readUtf8Strict(Path path) throws IOException {
        byte[] bytes = Files.readAllBytes(path);
        try {
            return StandardCharsets.UTF_8.newDecoder()
                    .onMalformedInput(CodingErrorAction.REPORT)
                    .onUnmappableCharacter(CodingErrorAction.REPORT)
                    .decode(ByteBuffer.wrap(bytes))
                    .toString();
        } catch (CharacterCodingException cause) {
            throw cause;
        }
    }

    static void replaceUtf8Atomically(Path target, String content) throws IOException {
        replaceWithWriter(target, temp -> Files.writeString(temp, content, StandardCharsets.UTF_8));
    }

    static void replaceWithWriter(Path target, TempWriter tempWriter) throws IOException {
        Path parent = target.toAbsolutePath().normalize().getParent();
        if (parent == null || !Files.isDirectory(parent, LinkOption.NOFOLLOW_LINKS)) {
            throw new IOException("target parent must exist");
        }
        Path temp = Files.createTempFile(parent, ".config-", ".tmp");
        IOException primary = null;
        try {
            tempWriter.write(temp);
            Files.move(temp, target, StandardCopyOption.ATOMIC_MOVE, StandardCopyOption.REPLACE_EXISTING);
        } catch (IOException failure) {
            primary = failure;
            throw failure;
        } finally {
            try {
                Files.deleteIfExists(temp);
            } catch (IOException cleanup) {
                if (primary != null) {
                    primary.addSuppressed(cleanup);
                } else {
                    throw cleanup;
                }
            }
        }
    }

    static List<String> listRegularFilesNoLinks(Path root, int maxDepth) throws IOException {
        try (Stream<Path> paths = Files.walk(root, maxDepth)) {
            return paths
                    .filter(path -> !Files.isSymbolicLink(path))
                    .filter(path -> Files.isRegularFile(path, LinkOption.NOFOLLOW_LINKS))
                    .map(path -> portableRelative(root, path))
                    .sorted()
                    .toList();
        }
    }

    // Reports use '/' as a protocol separator, independent of the host file system.
    static String portableRelative(Path root, Path path) {
        StringBuilder result = new StringBuilder();
        for (Path element : root.relativize(path)) {
            if (!result.isEmpty()) {
                result.append('/');
            }
            result.append(element);
        }
        return result.toString();
    }

    static long countTempFiles(Path directory) throws IOException {
        try (Stream<Path> paths = Files.list(directory)) {
            return paths.filter(path -> path.getFileName().toString().startsWith(".config-")).count();
        }
    }

    public static void main(String[] args) throws Exception {
        Path workspace = Files.createTempDirectory("nio-demo-");
        try {
            int assertions = 0;
            Path base = Files.createDirectories(workspace.resolve("allowed"));
            Path configDir = Files.createDirectories(base.resolve("config"));
            Path target = configDir.resolve("app.txt");
            Files.writeString(target, "old-complete", StandardCharsets.UTF_8);
            assertions = check("old-complete".equals(readUtf8Strict(target)), "initial strict read", assertions);

            Path resolved = resolveConfined(base, "config/app.txt");
            assertions = check(resolved.equals(target.toAbsolutePath().normalize()), "explicit base resolution", assertions);
            assertions = expectRejected(() -> resolveConfined(base, "../outside.txt"), assertions);
            assertions = expectRejected(() -> resolveConfined(base, target.toAbsolutePath().toString()), assertions);

            Path invalid = base.resolve("invalid.bin");
            Files.write(invalid, new byte[] {(byte) 0xc3, (byte) 0x28});
            IOException invalidFailure = null;
            try {
                readUtf8Strict(invalid);
            } catch (IOException expected) {
                invalidFailure = expected;
            }
            assertions = check(invalidFailure instanceof CharacterCodingException, "malformed UTF-8 rejected", assertions);
            assertions = check(invalidFailure != null, "invalid failure observed", assertions);

            IOException writeFailure = null;
            try {
                replaceWithWriter(target, temp -> {
                    try (BufferedWriter writer = Files.newBufferedWriter(temp, StandardCharsets.UTF_8)) {
                        writer.write("new-");
                        throw new IOException("injected temp write failure");
                    }
                });
            } catch (IOException expected) {
                writeFailure = expected;
            }
            assertions = check(writeFailure != null && "injected temp write failure".equals(writeFailure.getMessage()),
                    "injected write failure", assertions);
            boolean oldPreserved = "old-complete".equals(readUtf8Strict(target));
            assertions = check(oldPreserved, "old target preserved", assertions);
            assertions = check(countTempFiles(configDir) == 0, "failed temp cleaned", assertions);

            String replacement = "设备=A-17\n状态=运行\n";
            replaceUtf8Atomically(target, replacement);
            assertions = check(replacement.equals(readUtf8Strict(target)), "replacement round trip", assertions);
            assertions = check(countTempFiles(configDir) == 0, "successful temp consumed", assertions);
            assertions = check(Files.isRegularFile(target, LinkOption.NOFOLLOW_LINKS), "target regular file", assertions);

            Path scan = Files.createDirectories(base.resolve("scan"));
            Files.writeString(scan.resolve("a.txt"), "A", StandardCharsets.UTF_8);
            Path nested = Files.createDirectories(scan.resolve("nested"));
            Files.writeString(nested.resolve("b.txt"), "B", StandardCharsets.UTF_8);
            Path outside = Files.createDirectories(workspace.resolve("outside"));
            Path secret = outside.resolve("secret.txt");
            Files.writeString(secret, "SECRET", StandardCharsets.UTF_8);
            Path link = scan.resolve("external-link");
            Files.createSymbolicLink(link, outside);
            List<String> files = listRegularFilesNoLinks(scan, 4);
            assertions = check(files.equals(List.of("a.txt", "nested/b.txt")), "deterministic safe walk", assertions);
            assertions = check(Files.isSymbolicLink(link), "link fixture", assertions);
            assertions = check(files.stream().noneMatch(name -> name.contains("secret")), "external target filtered", assertions);

            Path lexical = scan.resolve("external-link/secret.txt").normalize();
            boolean lexicalInside = lexical.startsWith(scan.normalize());
            boolean realInside = lexical.toRealPath().startsWith(scan.toRealPath());
            assertions = check(lexicalInside, "link looks lexically inside", assertions);
            assertions = check(!realInside, "real target escapes", assertions);
            assertions = check(base.toRealPath().startsWith(workspace.toRealPath()), "real base inside workspace", assertions);

            Path binary = base.resolve("bytes.bin");
            byte[] binaryBytes = {(byte) 0x00, (byte) 0xff, (byte) 0x10};
            Files.write(binary, binaryBytes);
            assertions = check(Arrays.equals(binaryBytes, Files.readAllBytes(binary)), "binary bytes preserved", assertions);
            Path absent = resolveConfined(base, "not-created.txt");
            assertions = check(!Files.exists(absent), "Path creation does not create file", assertions);
            assertions = check(target.getParent().equals(configDir), "target parent explicit", assertions);

            System.out.println("initial.utf8=true");
            System.out.println("resolve.relative=" + resolved.equals(target.toAbsolutePath().normalize()));
            System.out.println("invalidUtf8=" + invalidFailure.getClass().getSimpleName());
            System.out.println("failure.oldPreserved=" + oldPreserved);
            System.out.println("failure.tempRemaining=0");
            System.out.println("success.roundTrip=" + replacement.equals(readUtf8Strict(target)));
            System.out.println("success.tempRemaining=" + countTempFiles(configDir));
            System.out.println("walk.files=" + String.join(",", files));
            System.out.println("walk.symlinkFiltered=" + files.stream().noneMatch(name -> name.contains("secret")));
            System.out.println("symlink.lexicalInside=" + lexicalInside);
            System.out.println("symlink.realInside=" + realInside);
            System.out.println("assertions=" + assertions + " passed");
        } finally {
            deleteTree(workspace);
        }
    }

    private static int expectRejected(Runnable action, int assertions) {
        try {
            action.run();
            throw new AssertionError("path must be rejected");
        } catch (IllegalArgumentException expected) {
            return assertions + 1;
        }
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
                if (failure != null) {
                    throw failure;
                }
                Files.delete(dir);
                return FileVisitResult.CONTINUE;
            }
        });
    }

    private static int check(boolean condition, String message, int assertions) {
        if (!condition) {
            throw new AssertionError(message);
        }
        return assertions + 1;
    }
}
