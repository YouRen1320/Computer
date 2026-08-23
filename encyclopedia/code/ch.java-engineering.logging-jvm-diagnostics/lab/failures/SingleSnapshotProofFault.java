public final class SingleSnapshotProofFault {
    private SingleSnapshotProofFault() {
    }

    public static void main(String[] args) {
        DiagnosticEvidenceLab.requireThreadSeries(1);
    }
}
