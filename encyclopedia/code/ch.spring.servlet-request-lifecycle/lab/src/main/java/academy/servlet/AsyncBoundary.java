package academy.servlet;

import jakarta.servlet.ServletRequest;
import java.util.Objects;
import java.util.concurrent.CompletableFuture;
import java.util.concurrent.CompletionStage;
import java.util.concurrent.Executor;

/**
 * Copies the small immutable input needed by background work before crossing a thread boundary.
 */
public final class AsyncBoundary {
    private AsyncBoundary() {
    }

    public static CompletionStage<Result> submit(ServletRequest request, Executor executor) {
        Objects.requireNonNull(request);
        Objects.requireNonNull(executor);
        Snapshot snapshot = new Snapshot(
                String.valueOf(request.getAttribute("requestId")),
                request.getParameter("equipmentId"));
        return CompletableFuture.supplyAsync(
                () -> new Result(snapshot.requestId(), snapshot.equipmentId(), Thread.currentThread().getName()),
                executor);
    }

    private record Snapshot(String requestId, String equipmentId) {
    }

    public record Result(String requestId, String equipmentId, String threadName) {
    }
}
