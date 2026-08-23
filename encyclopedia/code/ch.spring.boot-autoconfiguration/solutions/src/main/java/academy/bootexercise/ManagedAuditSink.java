package academy.bootexercise;

public final class ManagedAuditSink implements AuditSink {
    @Override
    public String destination() {
        return "console";
    }
}
