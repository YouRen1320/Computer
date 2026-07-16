public final class RecordArrayEqualityFailure {
    record Snapshot(int[] readings) {
    }

    public static void main(String[] args) {
        Snapshot first = new Snapshot(new int[]{1, 2});
        Snapshot second = new Snapshot(new int[]{1, 2});
        if (!first.equals(second)) {
            System.err.println("RECORD_ARRAY_EQUALITY_BROKEN sameContents=true recordEquals=false");
            System.exit(5);
        }
    }
}
