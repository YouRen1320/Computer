import java.util.Collections;
import java.util.List;

public final class UnsortedBinarySearchFailure {
    private UnsortedBinarySearchFailure() {
    }

    public static void main(String[] args) {
        List<Integer> unsorted = List.of(9, 1, 7, 3);
        if (Collections.binarySearch(unsorted, 9) < 0) {
            throw new IllegalStateException("UNSORTED_PRECONDITION");
        }
    }
}
