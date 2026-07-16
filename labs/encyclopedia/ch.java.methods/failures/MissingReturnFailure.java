public class MissingReturnFailure {
    static String label(int priority) {
        if (priority >= 4) {
            return "URGENT";
        }
    }
}
