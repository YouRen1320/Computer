public final class RepeatedSortFailure {
    private RepeatedSortFailure() {
    }

    public static void main(String[] args) {
        int queries = 4;
        int sortCalls = queries;
        if (sortCalls > 1) {
            throw new IllegalStateException("REPEATED_SORT");
        }
    }
}
