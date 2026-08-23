public final class MutableRecordFailure {
    record Snapshot(int[] readings) {
    }

    public static void main(String[] args) {
        int[] source = {8, 10};
        Snapshot snapshot = new Snapshot(source);
        source[0] = 99;
        if (snapshot.readings()[0] == 99) {
            System.err.println("LAB_RECORD_ALIAS_BROKEN expected=8 actual=99");
            System.exit(7);
        }
    }
}
