public final class MisclassifiedInputFailure {
    private MisclassifiedInputFailure() {
    }

    static String brokenHandle(String title) {
        try {
            if (title == null || title.isBlank()) {
                throw new IllegalArgumentException("title must have text");
            }
            return "CREATED";
        } catch (Exception ignoredType) {
            return "SYSTEM_ERROR";
        }
    }

    public static void main(String[] args) {
        if ("SYSTEM_ERROR".equals(brokenHandle(" "))) {
            System.err.println("INPUT_MISCLASSIFIED expected=INVALID_INPUT actual=SYSTEM_ERROR");
            System.exit(6);
        }
        throw new AssertionError("fixture did not misclassify the input");
    }
}
