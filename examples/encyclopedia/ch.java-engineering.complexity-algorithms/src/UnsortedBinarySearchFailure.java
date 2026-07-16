import java.util.Collections;
import java.util.List;

public final class UnsortedBinarySearchFailure {
    private UnsortedBinarySearchFailure() {
    }

    public static void main(String[] args) {
        List<Integer> unsorted = List.of(9, 1, 7, 3);
        int index = Collections.binarySearch(unsorted, 9);
        if (index < 0) {
            throw new IllegalStateException("UNSORTED_PRECONDITION");
        }
    }
}
