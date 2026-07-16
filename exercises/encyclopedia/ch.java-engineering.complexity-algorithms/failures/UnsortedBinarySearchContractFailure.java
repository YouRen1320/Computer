import java.util.Collections;
import java.util.List;

public final class UnsortedBinarySearchContractFailure {
    private UnsortedBinarySearchContractFailure() {
    }

    public static void main(String[] args) {
        if (Collections.binarySearch(List.of(9, 1, 7, 3), 9) < 0) {
            throw new IllegalStateException("UNSORTED_PRECONDITION");
        }
    }
}
