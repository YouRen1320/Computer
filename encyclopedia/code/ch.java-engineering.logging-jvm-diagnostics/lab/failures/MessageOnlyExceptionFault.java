public final class MessageOnlyExceptionFault {
    private MessageOnlyExceptionFault() {
    }

    public static void main(String[] args) {
        DiagnosticEvidenceLab.requireThrowableEvidence(null);
    }
}
