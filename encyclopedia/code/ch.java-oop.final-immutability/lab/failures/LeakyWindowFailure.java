public final class LeakyWindowFailure {
    private final int[] hours;

    private LeakyWindowFailure(int[] hours) {
        this.hours = hours.clone();
    }

    private int[] hours() {
        return hours;
    }

    public static void main(String[] args) {
        LeakyWindowFailure window = new LeakyWindowFailure(new int[]{8, 10});
        int[] leaked = window.hours();
        leaked[1] = 0;
        if (window.hours()[1] != 10) {
            System.err.println("OUTPUT_ALIAS_BROKEN expected=10 actual=" + window.hours()[1]);
            System.exit(1);
        }
    }
}
