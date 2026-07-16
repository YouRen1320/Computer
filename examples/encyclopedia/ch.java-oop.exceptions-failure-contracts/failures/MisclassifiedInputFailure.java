public final class MisclassifiedInputFailure {
    private MisclassifiedInputFailure() {
    }

    static final class InvalidInputException extends RuntimeException {
        InvalidInputException(String message) {
            super(message);
        }
    }

    static String brokenHandle(String title) {
        try {
            if (title == null || title.isBlank()) {
                throw new InvalidInputException("title must have text");
            }
            return "CREATED";
        } catch (Exception ignoredType) {
            return "SYSTEM_ERROR";
        }
    }

    public static void main(String[] args) {
        String actual = brokenHandle(" ");
        if ("SYSTEM_ERROR".equals(actual)) {
            System.err.println("INPUT_MISCLASSIFIED expected=INVALID_INPUT actual=SYSTEM_ERROR");
            System.exit(6);
        }
        throw new AssertionError("fixture did not misclassify the input");
    }
}
