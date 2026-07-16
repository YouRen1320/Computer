import java.util.concurrent.CancellationException;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.ExecutionException;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.TimeoutException;

/** One bounded solution; read only after attempting the public challenge. */
public final class ExecutorChallengeSolution {
    private record QuerySummary(String result, String failure, boolean virtual) {}

    public static void main(String[] args) throws Exception {
        QuerySummary summary = collect();
        System.out.println("result=" + summary.result());
        System.out.println("failure=" + summary.failure());
        System.out.println("virtual=" + summary.virtual());
        verifyTimeoutAndCancel();
        System.out.println("solution=PASS");
    }

    private static QuerySummary collect() throws Exception {
        ExecutorService executor = Executors.newVirtualThreadPerTaskExecutor();
        try (executor) {
            Future<String> success = executor.submit(() -> "WO-301:READY");
            Future<String> failure = executor.submit(() -> {
                throw new IllegalStateException("device-offline");
            });
            Future<Boolean> identity = executor.submit(() -> Thread.currentThread().isVirtual());
            String result = success.get(1, TimeUnit.SECONDS);
            try {
                failure.get(1, TimeUnit.SECONDS);
                throw new AssertionError("failure task unexpectedly returned");
            } catch (ExecutionException expected) {
                Throwable cause = expected.getCause();
                return new QuerySummary(
                        result,
                        cause.getClass().getSimpleName() + ":" + cause.getMessage(),
                        identity.get(1, TimeUnit.SECONDS));
            }
        }
    }

    private static void verifyTimeoutAndCancel() throws Exception {
        CountDownLatch started = new CountDownLatch(1);
        CountDownLatch release = new CountDownLatch(1);
        CountDownLatch finished = new CountDownLatch(1);
        boolean timedOut = false;
        boolean cancelled;
        ExecutorService executor = Executors.newVirtualThreadPerTaskExecutor();
        try (executor) {
            Future<String> future = executor.submit(() -> {
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
            try {
                if (!started.await(2, TimeUnit.SECONDS)) {
                    throw new AssertionError("task did not start");
                }
                try {
                    future.get(40, TimeUnit.MILLISECONDS);
                } catch (TimeoutException expected) {
                    timedOut = true;
                }
                cancelled = future.cancel(true);
                release.countDown();
                if (!finished.await(2, TimeUnit.SECONDS)) {
                    throw new AssertionError("task did not finish");
                }
                try {
                    future.get();
                    throw new AssertionError("cancelled Future returned");
                } catch (CancellationException expected) {
                    // Expected result protocol.
                }
            } finally {
                release.countDown();
                future.cancel(true);
            }
        }
        System.out.println("timeout=" + timedOut + ",cancelled=" + cancelled);
    }
}
