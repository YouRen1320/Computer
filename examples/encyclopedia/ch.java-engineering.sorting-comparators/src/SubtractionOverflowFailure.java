import java.util.Comparator;

public final class SubtractionOverflowFailure {
    private SubtractionOverflowFailure() {
    }

    public static void main(String[] args) {
        Comparator<Integer> broken = (left, right) -> left - right;
        if (broken.compare(Integer.MIN_VALUE, 1) > 0) {
            throw new IllegalStateException("OVERFLOW_ORDER");
        }
    }
}
