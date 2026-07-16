public final class QuadraticDedupFailure {
    private QuadraticDedupFailure() {
    }

    public static void main(String[] args) {
        int size = 100;
        long comparisons = (long) size * (size - 1) / 2;
        if (comparisons == 4_950) {
            throw new IllegalStateException("QUADRATIC_GROWTH");
        }
    }
}
