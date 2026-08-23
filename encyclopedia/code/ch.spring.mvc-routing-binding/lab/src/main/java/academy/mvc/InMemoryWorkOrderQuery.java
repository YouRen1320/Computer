package academy.mvc;

import java.util.Optional;
import java.util.concurrent.atomic.AtomicInteger;

public final class InMemoryWorkOrderQuery implements WorkOrderQuery {
    private final AtomicInteger calls = new AtomicInteger();

    @Override
    public Optional<String> find(long id, String tenantId) {
        calls.incrementAndGet();
        if (id == 42 && "tenant-a".equals(tenantId)) {
            return Optional.of("WO-42:CREATED");
        }
        return Optional.empty();
    }

    @Override
    public String page(int page, int size, String tenantId) {
        calls.incrementAndGet();
        return "page=%d,size=%d,tenant=%s,items=WO-42".formatted(page, size, tenantId);
    }

    public int callCount() {
        return calls.get();
    }
}
