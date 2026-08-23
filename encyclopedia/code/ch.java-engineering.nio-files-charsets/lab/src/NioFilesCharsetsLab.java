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

public final class NioFilesCharsetsLab {
    private NioFilesCharsetsLab() {
    }

    @FunctionalInterface
    interface TempWriter {
        void write(Path temp) throws IOException;
    }

    // The configured base is the authority; the process working directory is not.
    static Path resolveUnder(Path base, String relative) {
        if (base == null || relative == null || relative.isBlank()) {
            throw new IllegalArgumentException("base and non-blank relative path required");
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

    // The temp file shares the target directory so an atomic provider move can be requested.
    static void replaceWithTemp(Path target, TempWriter writer) throws IOException {
        Path normalizedTarget = target.toAbsolutePath().normalize();
        Path parent = normalizedTarget.getParent();
        if (parent == null || !Files.isDirectory(parent, LinkOption.NOFOLLOW_LINKS)) {
            throw new IOException("target parent must already exist");
        }
        Path temp = Files.createTempFile(parent, ".lab-", ".tmp");
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

    static List<String> regularFilesNoLinks(Path root, int maxDepth) throws IOException {
        try (Stream<Path> paths = Files.walk(root, maxDepth)) {
            return paths
                    .filter(path -> !Files.isSymbolicLink(path))
                    .filter(path -> Files.isRegularFile(path, LinkOption.NOFOLLOW_LINKS))
                    .map(path -> portableRelative(root, path))
                    .sorted()
                    .toList();
        }
    }

    // Slash-separated evidence stays byte-identical on Unix and Windows providers.
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

    static long countTemps(Path directory) throws IOException {
        try (Stream<Path> paths = Files.list(directory)) {
            return paths.filter(path -> path.getFileName().toString().startsWith(".lab-")).count();
        }
    }

    public static void main(String[] args) throws Exception {
        Path workspace = Files.createTempDirectory("nio-lab-");
        try {
            int assertions = 0;
            Path base = Files.createDirectories(workspace.resolve("configured-base"));
            Path config = Files.createDirectories(base.resolve("config"));
            Path target = config.resolve("device.txt");
            String original = "设备=A-17\n状态=待机\n";
            Files.writeString(target, original, StandardCharsets.UTF_8);
            assertions = check(original.equals(readUtf8Strict(target)), "UTF-8 round trip", assertions);
            assertions = check(resolveUnder(base, "config/device.txt").equals(target.toAbsolutePath().normalize()),
                    "configured base used", assertions);
            assertions = expectRejected(() -> resolveUnder(base, "../escape.txt"), assertions);
            assertions = expectRejected(() -> resolveUnder(base, target.toAbsolutePath().toString()), assertions);
            assertions = expectRejected(() -> resolveUnder(base, " "), assertions);

            Path malformed = base.resolve("malformed.bin");
            Files.write(malformed, new byte[] {(byte) 0xc3, (byte) 0x28});
            IOException malformedFailure = null;
            try {
                readUtf8Strict(malformed);
            } catch (IOException expected) {
                malformedFailure = expected;
            }
            assertions = check(malformedFailure instanceof CharacterCodingException,
                    "malformed input reported", assertions);

            IOException injected = null;
            try {
                replaceWithTemp(target, temp -> {
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
                    "injected failure observed", assertions);
            assertions = check(oldPreserved, "old target preserved", assertions);
            assertions = check(countTemps(config) == 0, "failed temp cleaned", assertions);

            String replacement = "设备=A-17\n状态=运行\n";
            replaceWithTemp(target, temp -> Files.writeString(temp, replacement, StandardCharsets.UTF_8));
            assertions = check(replacement.equals(readUtf8Strict(target)), "replacement complete", assertions);
            assertions = check(Files.size(target) == replacement.getBytes(StandardCharsets.UTF_8).length,
                    "text byte length uses UTF-8", assertions);
            assertions = check(countTemps(config) == 0, "successful temp consumed", assertions);
            assertions = check(Files.isRegularFile(target, LinkOption.NOFOLLOW_LINKS), "target regular", assertions);

            Path tree = Files.createDirectories(base.resolve("tree"));
            Files.writeString(tree.resolve("a.txt"), "A", StandardCharsets.UTF_8);
            Path nested = Files.createDirectories(tree.resolve("nested"));
            Files.writeString(nested.resolve("b.txt"), "B", StandardCharsets.UTF_8);
            Path outside = Files.createDirectories(workspace.resolve("outside"));
            Files.writeString(outside.resolve("secret.txt"), "secret", StandardCharsets.UTF_8);
            Path link = tree.resolve("external");
            Files.createSymbolicLink(link, outside);
            List<String> depthOne = regularFilesNoLinks(tree, 1);
            List<String> depthFour = regularFilesNoLinks(tree, 4);
            assertions = check(depthOne.equals(List.of("a.txt")), "max depth applied", assertions);
            assertions = check(depthFour.equals(List.of("a.txt", "nested/b.txt")), "sorted traversal", assertions);
            assertions = check(Files.isSymbolicLink(link), "symbolic link fixture", assertions);
            assertions = check(depthFour.stream().noneMatch(name -> name.contains("secret")),
                    "external file not traversed", assertions);
            Path lexicalSecret = link.resolve("secret.txt").normalize();
            boolean lexicalInside = lexicalSecret.startsWith(tree.normalize());
            boolean realEscape = !lexicalSecret.toRealPath().startsWith(tree.toRealPath());
            assertions = check(lexicalInside, "lexical path appears inside", assertions);
            assertions = check(realEscape, "real path reveals escape", assertions);
            assertions = check(!Files.isRegularFile(link, LinkOption.NOFOLLOW_LINKS),
                    "NOFOLLOW does not classify directory link as file", assertions);

            Path bytesFile = base.resolve("payload.bin");
            byte[] bytes = {(byte) 0x00, (byte) 0xff, (byte) 0x7f, (byte) 0x10};
            Files.write(bytesFile, bytes);
            assertions = check(Arrays.equals(bytes, Files.readAllBytes(bytesFile)), "binary preserved", assertions);
            assertions = check(!Files.exists(resolveUnder(base, "missing.txt")), "Path is not file creation", assertions);
            assertions = check(target.getParent().equals(config), "target parent explicit", assertions);
            assertions = check(base.toRealPath().startsWith(workspace.toRealPath()), "base rooted in sandbox", assertions);

            System.out.println("lab.utf8=true");
            System.out.println("lab.invalid=" + malformedFailure.getClass().getSimpleName());
            System.out.println("lab.failure.oldPreserved=" + oldPreserved);
            System.out.println("lab.failure.tempRemaining=" + countTemps(config));
            System.out.println("lab.success=true");
            System.out.println("lab.walk.depth1=" + String.join(",", depthOne));
            System.out.println("lab.walk.depth4=" + String.join(",", depthFour));
            System.out.println("lab.symlinkFiltered=" + depthFour.stream().noneMatch(name -> name.contains("secret")));
            System.out.println("lab.realEscape=" + realEscape);
            System.out.println("lab.assertions=" + assertions + " passed");
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

    static void deleteTree(Path root) throws IOException {
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
