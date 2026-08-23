public final class MisclassifiedInputFailure {
    private MisclassifiedInputFailure() {
    }

    public static void main(String[] args) {
        String result;
        try {
            throw new IllegalArgumentException("title must have text");
        } catch (Exception ignoredType) {
            result = "SYSTEM_ERROR";
        }
        if ("SYSTEM_ERROR".equals(result)) {
            System.err.println("INPUT_MISCLASSIFIED expected=INVALID_INPUT actual=SYSTEM_ERROR");
            System.exit(6);
        }
        throw new AssertionError("fixture did not misclassify the input");
    }
}
