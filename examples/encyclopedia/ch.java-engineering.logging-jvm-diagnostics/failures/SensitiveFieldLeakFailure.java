public final class SensitiveFieldLeakFailure {
    private SensitiveFieldLeakFailure() {
    }

    public static void main(String[] args) {
        LoggingDiagnosticsExample.requireSecretAbsent(
                "event=request.failed authorization=Bearer-demo-secret",
                "Bearer-demo-secret");
    }
}
