public final class MissingCorrelationFailure {
    private MissingCorrelationFailure() {
    }

    public static void main(String[] args) {
        LoggingDiagnosticsExample.requireValidCorrelation("bad\nid");
    }
}
