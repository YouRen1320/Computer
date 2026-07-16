import java.util.NoSuchElementException;
import java.util.Optional;

public final class OptionalGetFailure {
    private OptionalGetFailure() {
    }

    public static void main(String[] args) {
        try {
            Optional.<String>empty().get();
        } catch (NoSuchElementException expected) {
            throw new IllegalStateException("OPTIONAL_EMPTY_GET", expected);
        }
        throw new AssertionError("OPTIONAL_EMPTY_GET was not rejected");
    }
}
