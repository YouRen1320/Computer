public final class SecretLeakFault {
    private SecretLeakFault() {
    }

    public static void main(String[] args) {
        DiagnosticEvidenceLab.requireSecretAbsent(
                "event=dispatch.failed authorization=Bearer-training-secret",
                "Bearer-training-secret");
    }
}
