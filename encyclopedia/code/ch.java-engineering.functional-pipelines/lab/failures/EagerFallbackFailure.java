import java.util.Optional;

public final class EagerFallbackFailure {
    private EagerFallbackFailure() {
    }

    private static String fallback() {
        throw new IllegalStateException("EAGER_FALLBACK");
    }

    public static void main(String[] args) {
        System.out.println(Optional.of("known").orElse(fallback()));
    }
}
