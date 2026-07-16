public final class SwallowedFailure {
    private SwallowedFailure() {
    }

    static String brokenCreate() {
        try {
            throw new Exception("gateway unavailable");
        } catch (Exception ignored) {
            return null;
        }
    }

    public static void main(String[] args) {
        if (brokenCreate() == null) {
            System.err.println("SWALLOWED_FAILURE result=null causeLost=true");
            System.exit(4);
        }
        throw new AssertionError("fixture did not swallow the failure");
    }
}
