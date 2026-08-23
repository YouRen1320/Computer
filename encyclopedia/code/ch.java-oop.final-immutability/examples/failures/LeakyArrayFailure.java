public final class LeakyArrayFailure {
    private final int[] hours;

    private LeakyArrayFailure(int[] hours) {
        this.hours = hours;
    }

    private int firstHour() {
        return hours[0];
    }

    public static void main(String[] args) {
        int[] source = {8, 10};
        LeakyArrayFailure window = new LeakyArrayFailure(source);
        source[0] = 23;
        if (window.firstHour() != 8) {
            System.err.println("INPUT_ALIAS_BROKEN expected=8 actual=" + window.firstHour());
            System.exit(1);
        }
    }
}
