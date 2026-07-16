public final class SwallowedFailure {
    private SwallowedFailure() {
    }

    public static void main(String[] args) {
        String result;
        try {
            throw new Exception("gateway unavailable");
        } catch (Exception ignored) {
            result = null;
        }
        if (result == null) {
            System.err.println("SWALLOWED_FAILURE result=null causeLost=true");
            System.exit(4);
        }
        throw new AssertionError("fixture did not swallow the failure");
    }
}
