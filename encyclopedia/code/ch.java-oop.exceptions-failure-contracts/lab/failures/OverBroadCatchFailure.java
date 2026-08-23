public final class OverBroadCatchFailure {
    private OverBroadCatchFailure() {
    }

    static String brokenHandle() {
        try {
            String internal = null;
            return internal.strip();
        } catch (Exception ignoredBug) {
            return "INVALID_INPUT";
        }
    }

    public static void main(String[] args) {
        if ("INVALID_INPUT".equals(brokenHandle())) {
            System.err.println("BUG_MISCLASSIFIED exception=NullPointerException actual=INVALID_INPUT");
            System.exit(7);
        }
        throw new AssertionError("fixture did not hide the program bug");
    }
}
