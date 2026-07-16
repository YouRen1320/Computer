import java.io.IOException;
import java.io.Writer;
import java.nio.charset.StandardCharsets;
import java.nio.file.FileVisitOption;
import java.nio.file.FileVisitResult;
import java.nio.file.Files;
import java.nio.file.LinkOption;
import java.nio.file.Path;
import java.nio.file.SimpleFileVisitor;
import java.nio.file.StandardOpenOption;
import java.nio.file.attribute.BasicFileAttributes;
import java.util.List;
import java.util.stream.Stream;

public final class NioSafetyChallenge {
    private NioSafetyChallenge() {
    }

    record Outcome(int status, String diagnostic) {
    }

    static String readTextBroken(Path path) throws IOException {
        // TODO：显式声明 UTF-8，并让非法字节可诊断。
        return new String(Files.readAllBytes(path));
    }

    static void replaceBroken(Path target, String content, boolean injectFailure) throws IOException {
        // TODO：在同目录 temp 完整写入；injectFailure 时留住旧目标并清理 temp。
        try (Writer writer = Files.newBufferedWriter(target, StandardCharsets.UTF_8,
                StandardOpenOption.TRUNCATE_EXISTING)) {
            writer.write(injectFailure ? "new-" : content);
            if (injectFailure) {
                throw new IOException("injected interruption");
            }
        }
    }

    static Path resolveBroken(Path configuredBase, String relative) {
        // TODO：configuredBase 必须成为解析基准，并拒绝逃逸。
        return Path.of(relative).toAbsolutePath().normalize();
    }

    static List<Path> walkBroken(Path root) throws IOException {
        // TODO：最多访问深度 2，不跟随链接，并明确结果顺序。
        try (Stream<Path> paths = Files.walk(root, 4, FileVisitOption.FOLLOW_LINKS)) {
            return paths.filter(Files::isRegularFile).toList();
        }
    }

    public static void main(String[] args) throws Exception {
        Path workspace = Files.createTempDirectory("nio-challenge-");
        Outcome outcome;
        try {
            outcome = runChallenge(workspace);
        } finally {
            deleteTree(workspace);
        }
        if (outcome.status() != 0) {
            System.err.println(outcome.diagnostic());
            System.exit(outcome.status());
        }
        System.out.println(outcome.diagnostic());
    }

    private static Outcome runChallenge(Path workspace) throws Exception {
        Path configuredBase = Files.createDirectories(workspace.resolve("configured"));
        Path text = configuredBase.resolve("device.txt");
        String original = "设备=A-17";
        Files.write(text, original.getBytes(StandardCharsets.UTF_8));
        if (!original.equals(readTextBroken(text))) {
            return new Outcome(8, "STARTER_DEFAULT_CHARSET expectedUtf8=true actualRoundTrip=false");
        }

        Path malformed = configuredBase.resolve("malformed.bin");
        Files.write(malformed, new byte[] {(byte) 0xc3, (byte) 0x28});
        boolean malformedRejected = false;
        try {
            readTextBroken(malformed);
        } catch (IOException expected) {
            malformedRejected = true;
        }
        if (!malformedRejected) {
            return new Outcome(12, "STARTER_MALFORMED_UTF8 expected=IOException actual=decoded-text");
        }

        Path target = configuredBase.resolve("config.txt");
        Files.writeString(target, "old-complete", StandardCharsets.UTF_8);
        List<String> entriesBeforeFailure = entryNames(configuredBase);
        try {
            replaceBroken(target, "new-complete", true);
        } catch (IOException expected) {
            // Inspect the persisted state after the injected failure.
        }
        boolean oldPreserved = "old-complete".equals(Files.readString(target, StandardCharsets.UTF_8));
        if (!oldPreserved) {
            return new Outcome(9, "STARTER_DIRECT_OVERWRITE expected=old-complete actual=new-");
        }
        List<String> entriesAfterFailure = entryNames(configuredBase);
        if (!entriesAfterFailure.equals(entriesBeforeFailure)) {
            return new Outcome(13, "STARTER_TEMP_RESIDUE phase=failure");
        }

        replaceBroken(target, "new-complete", false);
        boolean replacementComplete = "new-complete".equals(Files.readString(target, StandardCharsets.UTF_8));
        if (!replacementComplete) {
            return new Outcome(14, "STARTER_REPLACEMENT expected=new-complete actual=incomplete");
        }
        List<String> entriesAfterSuccess = entryNames(configuredBase);
        if (!entriesAfterSuccess.equals(entriesBeforeFailure)) {
            return new Outcome(15, "STARTER_TEMP_RESIDUE phase=success");
        }

        Path resolved = resolveBroken(configuredBase, "config.txt");
        boolean configuredBaseUsed = resolved.equals(target.toAbsolutePath().normalize());
        if (!configuredBaseUsed) {
            return new Outcome(10, "STARTER_RELATIVE_BASE expectedConfiguredBase=true actualConfiguredBase=false");
        }
        boolean escapeRejected = rejected(() -> resolveBroken(configuredBase, "../escape.txt"));
        if (!escapeRejected) {
            return new Outcome(16, "STARTER_PATH_ESCAPE expectedRejected=true actualRejected=false");
        }
        boolean absoluteRejected = rejected(() -> resolveBroken(configuredBase, target.toAbsolutePath().toString()));
        if (!absoluteRejected) {
            return new Outcome(17, "STARTER_ABSOLUTE_PATH expectedRejected=true actualRejected=false");
        }

        Path tree = Files.createDirectory(configuredBase.resolve("tree"));
        Files.writeString(tree.resolve("a.txt"), "A", StandardCharsets.UTF_8);
        Path nested = Files.createDirectory(tree.resolve("nested"));
        Files.writeString(nested.resolve("b.txt"), "B", StandardCharsets.UTF_8);
        Path deeper = Files.createDirectory(nested.resolve("deeper"));
        Files.writeString(deeper.resolve("c.txt"), "C", StandardCharsets.UTF_8);
        Path outside = Files.createDirectory(workspace.resolve("outside"));
        Files.writeString(outside.resolve("secret.txt"), "secret", StandardCharsets.UTF_8);
        Path externalLink = tree.resolve("external");
        Files.createSymbolicLink(externalLink, outside);
        List<Path> visited = walkBroken(tree);
        boolean secretVisited = visited.stream()
                .anyMatch(path -> path.getFileName().toString().equals("secret.txt"));
        if (secretVisited) {
            return new Outcome(11, "STARTER_FOLLOW_LINKS secretVisited=true");
        }
        List<String> reportPaths = visited.stream()
                .map(path -> portableRelative(tree, path))
                .toList();
        if (!reportPaths.equals(List.of("a.txt", "nested/b.txt"))) {
            return new Outcome(18, "STARTER_WALK_ORDER expected=a.txt,nested/b.txt actual="
                    + String.join(",", reportPaths));
        }

        int assertions = 0;
        assertions = check(original.equals(readTextBroken(text)), "UTF-8", assertions);
        assertions = check(malformedRejected, "malformed rejected", assertions);
        assertions = check(oldPreserved, "old target", assertions);
        assertions = check(entriesAfterFailure.equals(entriesBeforeFailure), "failure cleanup", assertions);
        assertions = check(replacementComplete, "replacement complete", assertions);
        assertions = check(entriesAfterSuccess.equals(entriesBeforeFailure), "success cleanup", assertions);
        assertions = check(configuredBaseUsed, "configured base", assertions);
        assertions = check(escapeRejected, "escape rejected", assertions);
        assertions = check(absoluteRejected, "absolute rejected", assertions);
        assertions = check(!secretVisited, "link filtered", assertions);
        assertions = check(reportPaths.equals(List.of("a.txt", "nested/b.txt")), "stable walk", assertions);
        assertions = check(Files.isSymbolicLink(externalLink), "link fixture", assertions);
        return new Outcome(0, "challenge.assertions=" + assertions + " passed");
    }

    static List<String> entryNames(Path directory) throws IOException {
        try (Stream<Path> paths = Files.list(directory)) {
            return paths.map(path -> path.getFileName().toString()).sorted().toList();
        }
    }

    static boolean rejected(Runnable action) {
        try {
            action.run();
            return false;
        } catch (IllegalArgumentException expected) {
            return true;
        }
    }

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
