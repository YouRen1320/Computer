public final class OneShotBenchmarkFault {
    private OneShotBenchmarkFault() {
    }

    public static void main(String[] args) {
        DiagnosticEvidenceLab.requirePerformanceEvidence(1, 0);
    }
}
