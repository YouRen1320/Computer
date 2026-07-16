import java.util.concurrent.CountDownLatch;
import java.util.concurrent.ExecutionException;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.TimeoutException;

/** A deterministic, offline tour of Future outcomes and virtual-thread identity. */
public final class ExecutorsVirtualThreadsDemo {
    private record QueryResult(String workOrderId, String state) {
        String display() {
            return workOrderId + ":" + state;
        }
    }

    public static void main(String[] args) throws Exception {
        runPlatformPoolExamples();
        runVirtualThreadExample();
    }

    private static void runPlatformPoolExamples() throws Exception {
        ExecutorService executor = Executors.newFixedThreadPool(
                2,
                Thread.ofPlatform().name("fc-query-", 0).factory());
        try {
            Future<QueryResult> success = executor.submit(
                    () -> new QueryResult("WO-101", "READY"));
            Future<QueryResult> failure = executor.submit(() -> {
                throw new IllegalStateException("device-offline");
            });

            System.out.println("success=" + success.get(1, TimeUnit.SECONDS).display());
            try {
                failure.get(1, TimeUnit.SECONDS);
                throw new AssertionError("failure task unexpectedly returned");
            } catch (ExecutionException expected) {
                Throwable cause = expected.getCause();
                System.out.println("failure=" + cause.getClass().getSimpleName() + ":" + cause.getMessage());
            }

            CountDownLatch started = new CountDownLatch(1);
            CountDownLatch release = new CountDownLatch(1);
            CountDownLatch finished = new CountDownLatch(1);
            Future<String> waiting = executor.submit(() -> {
                started.countDown();
                try {
                    release.await();
                    return "released";
                } catch (InterruptedException interrupted) {
                    Thread.currentThread().interrupt();
                    return "interrupted";
                } finally {
                    finished.countDown();
                }
            });

            await(started, "waiting task did not start");
            try {
                waiting.get(30, TimeUnit.MILLISECONDS);
                throw new AssertionError("waiting task unexpectedly completed");
            } catch (TimeoutException expected) {
                System.out.println("timeout=" + expected.getClass().getSimpleName());
            }

            boolean cancelRequested = waiting.cancel(true);
            release.countDown();
            await(finished, "cancelled task did not finish cooperatively");
            System.out.println("cancel-requested=" + cancelRequested + ",state=" + waiting.state());
        } finally {
            shutdownAndAwait(executor);
        }
        System.out.println("fixed-terminated=" + executor.isTerminated());
    }

    private static void runVirtualThreadExample() throws Exception {
        ExecutorService executor = Executors.newVirtualThreadPerTaskExecutor();
        try (executor) {
            Future<Boolean> virtual = executor.submit(() -> Thread.currentThread().isVirtual());
            System.out.println("virtual=" + virtual.get(1, TimeUnit.SECONDS));
        }
        System.out.println("virtual-terminated=" + executor.isTerminated());
    }

    private static void await(CountDownLatch latch, String message) throws InterruptedException {
        if (!latch.await(2, TimeUnit.SECONDS)) {
            throw new AssertionError(message);
        }
    }

    private static void shutdownAndAwait(ExecutorService executor) throws InterruptedException {
        executor.shutdown();
        if (!executor.awaitTermination(2, TimeUnit.SECONDS)) {
            executor.shutdownNow();
            if (!executor.awaitTermination(2, TimeUnit.SECONDS)) {
                throw new AssertionError("executor did not terminate");
            }
        }
    }
}
