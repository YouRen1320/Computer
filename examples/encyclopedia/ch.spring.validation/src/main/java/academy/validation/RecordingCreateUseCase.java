package academy.validation;

import java.util.concurrent.atomic.AtomicInteger;

public final class RecordingCreateUseCase {
    private final AtomicInteger calls = new AtomicInteger();

    public long create(CreateWorkOrderRequest request) {
        calls.incrementAndGet();
        return 42;
    }

    public int callCount() {
        return calls.get();
    }
}
