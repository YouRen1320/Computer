package academy.boot.autoconfigure;

import java.util.concurrent.atomic.AtomicInteger;

import academy.audit.AuditSink;

public final class ManagedAuditSink implements AuditSink, AutoCloseable {
    private static final AtomicInteger CLOSE_COUNT = new AtomicInteger();

    @Override
    public String destination() {
        return "console";
    }

    @Override
    public void close() {
        CLOSE_COUNT.incrementAndGet();
    }

    public static int closeCount() {
        return CLOSE_COUNT.get();
    }

    public static void resetCloseCount() {
        CLOSE_COUNT.set(0);
    }
}
