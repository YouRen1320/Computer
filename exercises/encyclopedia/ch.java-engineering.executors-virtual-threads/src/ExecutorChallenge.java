import java.util.concurrent.ExecutionException;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;
import java.util.concurrent.TimeUnit;

/** Public starter: it intentionally loses the task's real failure cause. */
public final class ExecutorChallenge {
    private record QuerySummary(String result, String failure) {}

    public static void main(String[] args) throws Exception {
        QuerySummary summary = collect();
        String expectedFailure = "IllegalStateException:device-offline";
        if (!expectedFailure.equals(summary.failure())) {
            System.out.println("starter-failure=expected cause-preserved actual=" + summary.failure());
            System.exit(1);
        }
        System.out.println("challenge=PASS");
    }

    private static QuerySummary collect() throws Exception {
        ExecutorService executor = Executors.newVirtualThreadPerTaskExecutor();
        try (executor) {
            Future<String> success = executor.submit(() -> "WO-301:READY");
            Future<String> failure = executor.submit(() -> {
                throw new IllegalStateException("device-offline");
            });
            String result = success.get(1, TimeUnit.SECONDS);
            try {
                failure.get(1, TimeUnit.SECONDS);
                return new QuerySummary(result, "NONE");
            } catch (ExecutionException ignored) {
                // TODO: preserve the actual cause type and message.
                return new QuerySummary(result, "UNKNOWN");
            }
        }
    }
}
