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

public final class NioSafetySolution {
    private NioSafetySolution() {
    }

    @FunctionalInterface
    interface TempWriter {
        void write(Path temp) throws IOException;
    }

    static String readUtf8Strict(Path path) throws IOException {
        try {
            return StandardCharsets.UTF_8.newDecoder()
                    .onMalformedInput(CodingErrorAction.REPORT)
                    .onUnmappableCharacter(CodingErrorAction.REPORT)
                    .decode(ByteBuffer.wrap(Files.readAllBytes(path)))
                    .toString();
        } catch (CharacterCodingException cause) {
            throw cause;
        }
    }

    static Path resolveConfined(Path base, String relative) {
        if (base == null || relative == null || relative.isBlank()) {
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

    static void replaceUtf8(Path target, String content) throws IOException {
        replaceWithWriter(target, temp -> Files.writeString(temp, content, StandardCharsets.UTF_8));
    }

    static void replaceWithWriter(Path target, TempWriter writer) throws IOException {
        Path normalizedTarget = target.toAbsolutePath().normalize();
        Path parent = normalizedTarget.getParent();
        if (parent == null || !Files.isDirectory(parent, LinkOption.NOFOLLOW_LINKS)) {
            throw new IOException("target parent must exist");
        }
        Path temp = Files.createTempFile(parent, ".solution-", ".tmp");
        IOException primary = null;
        try {
            writer.write(temp);
            Files.move(temp, normalizedTarget,
                    StandardCopyOption.ATOMIC_MOVE,
                    StandardCopyOption.REPLACE_EXISTING);
        } catch (IOException failure) {
            primary = failure;
            throw failure;
        } finally {
            try {
                Files.deleteIfExists(temp);
            } catch (IOException cleanup) {
                if (primary == null) {
                    throw cleanup;
                }
                primary.addSuppressed(cleanup);
            }
        }
    }

    static List<String> walkNoLinks(Path root, int maxDepth) throws IOException {
        try (Stream<Path> paths = Files.walk(root, maxDepth)) {
            return paths
                    .filter(path -> !Files.isSymbolicLink(path))
                    .filter(path -> Files.isRegularFile(path, LinkOption.NOFOLLOW_LINKS))
                    .map(path -> portableRelative(root, path))
                    .sorted()
                    .toList();
        }
    }

    // Verification output is a portable report format, not a native path serialization.
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

    static long tempCount(Path directory) throws IOException {
        try (Stream<Path> paths = Files.list(directory)) {
            return paths.filter(path -> path.getFileName().toString().startsWith(".solution-")).count();
        }
    }

    public static void main(String[] args) throws Exception {
        Path workspace = Files.createTempDirectory("nio-solution-");
        try {
            int assertions = 0;
            Path base = Files.createDirectories(workspace.resolve("base"));
            Path config = Files.createDirectories(base.resolve("config"));
            Path target = config.resolve("device.txt");
            String original = "设备=A-17\n状态=待机\n";
            Files.writeString(target, original, StandardCharsets.UTF_8);
            assertions = check(original.equals(readUtf8Strict(target)), "initial UTF-8", assertions);
            assertions = check(resolveConfined(base, "config/device.txt").equals(target.toAbsolutePath().normalize()),
                    "configured base", assertions);
            assertions = reject(() -> resolveConfined(base, "../escape.txt"), assertions);
            assertions = reject(() -> resolveConfined(base, target.toAbsolutePath().toString()), assertions);

            Path malformed = base.resolve("malformed.bin");
            Files.write(malformed, new byte[] {(byte) 0xc3, (byte) 0x28});
            IOException malformedFailure = null;
            try {
                readUtf8Strict(malformed);
            } catch (IOException expected) {
                malformedFailure = expected;
            }
            assertions = check(malformedFailure instanceof CharacterCodingException,
                    "malformed UTF-8 rejected", assertions);

            IOException injected = null;
            try {
                replaceWithWriter(target, temp -> {
                    try (BufferedWriter output = Files.newBufferedWriter(temp, StandardCharsets.UTF_8)) {
                        output.write("partial-");
                        throw new IOException("injected temp failure");
                    }
                });
            } catch (IOException expected) {
                injected = expected;
            }
            boolean oldPreserved = original.equals(readUtf8Strict(target));
            assertions = check(injected != null && "injected temp failure".equals(injected.getMessage()),
                    "write failure retained", assertions);
            assertions = check(oldPreserved, "old target preserved", assertions);
            assertions = check(tempCount(config) == 0, "failed temp cleaned", assertions);

            String replacement = "设备=A-17\n状态=运行\n";
            replaceUtf8(target, replacement);
            assertions = check(replacement.equals(readUtf8Strict(target)), "replacement complete", assertions);
            assertions = check(tempCount(config) == 0, "success temp consumed", assertions);
            assertions = check(Files.size(target) == replacement.getBytes(StandardCharsets.UTF_8).length,
                    "UTF-8 byte size", assertions);

            Path tree = Files.createDirectories(base.resolve("tree"));
            Files.writeString(tree.resolve("a.txt"), "A", StandardCharsets.UTF_8);
            Path nested = Files.createDirectory(tree.resolve("nested"));
            Files.writeString(nested.resolve("b.txt"), "B", StandardCharsets.UTF_8);
            Path outside = Files.createDirectory(workspace.resolve("outside"));
            Files.writeString(outside.resolve("secret.txt"), "secret", StandardCharsets.UTF_8);
            Path link = tree.resolve("external");
            Files.createSymbolicLink(link, outside);
            List<String> files = walkNoLinks(tree, 4);
            assertions = check(files.equals(List.of("a.txt", "nested/b.txt")), "stable traversal", assertions);
            assertions = check(Files.isSymbolicLink(link), "link fixture", assertions);
            assertions = check(files.stream().noneMatch(name -> name.contains("secret")),
                    "external secret filtered", assertions);
            Path candidate = link.resolve("secret.txt").normalize();
            boolean lexicalInside = candidate.startsWith(tree.normalize());
            boolean realEscape = !candidate.toRealPath().startsWith(tree.toRealPath());
            assertions = check(lexicalInside, "lexical containment", assertions);
            assertions = check(realEscape, "real path escape", assertions);

            byte[] bytes = {(byte) 0x00, (byte) 0xff, (byte) 0x10};
            Path binary = base.resolve("payload.bin");
            Files.write(binary, bytes);
            assertions = check(Arrays.equals(bytes, Files.readAllBytes(binary)), "binary bytes", assertions);
            assertions = check(!Files.exists(resolveConfined(base, "missing.txt")), "Path is only a locator", assertions);

            System.out.println("solution.utf8=true");
            System.out.println("solution.invalid=" + malformedFailure.getClass().getSimpleName());
            System.out.println("solution.failure.oldPreserved=" + oldPreserved);
            System.out.println("solution.failure.tempRemaining=" + tempCount(config));
            System.out.println("solution.success=true");
            System.out.println("solution.walk=" + String.join(",", files));
            System.out.println("solution.symlinkFiltered=" + files.stream().noneMatch(name -> name.contains("secret")));
            System.out.println("solution.realEscape=" + realEscape);
            System.out.println("solution.assertions=" + assertions + " passed");
        } finally {
            deleteTree(workspace);
        }
    }

    private static int reject(Runnable action, int assertions) {
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
