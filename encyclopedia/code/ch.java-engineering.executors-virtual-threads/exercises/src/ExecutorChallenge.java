import java.util.concurrent.CancellationException;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.ExecutionException;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;
import java.util.concurrent.RejectedExecutionException;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.TimeoutException;

/** Public starter for bounded Future failure, timeout, cancellation, and executor lifecycle contracts. */
public final class ExecutorChallenge {
    private record QuerySummary(String result, String failure, boolean virtual) {
    }

    private record TimeoutCancel(boolean timedOut, boolean cancelled) {
    }

    private record Lifecycle(boolean terminated, boolean rejectedAfterClose) {
    }

    public static void main(String[] args) throws Exception {
        QuerySummary summary = collect();
        String expectedFailure = "IllegalStateException:device-offline";
        if (!expectedFailure.equals(summary.failure())) {
            System.out.println("starter-failure=expected cause-preserved actual=" + summary.failure());
            System.exit(1);
        }

        TimeoutCancel timeoutCancel = verifyTimeoutAndCancel();
        if (!timeoutCancel.timedOut() || !timeoutCancel.cancelled()) {
            throw new IllegalStateException("TIMEOUT_CANCEL_CONTRACT complete TODO 2..4");
        }

        Lifecycle lifecycle = verifyLifecycle();
        if (!lifecycle.terminated() || !lifecycle.rejectedAfterClose()) {
            throw new IllegalStateException("EXECUTOR_LIFECYCLE_CONTRACT complete TODO 5");
        }

        System.out.println("result=" + summary.result());
        System.out.println("failure=" + summary.failure());
        System.out.println("virtual=" + summary.virtual());
        System.out.println("timeout=" + timeoutCancel.timedOut() + ",cancelled=" + timeoutCancel.cancelled());
        System.out.println("terminated=" + lifecycle.terminated()
                + ",rejectedAfterClose=" + lifecycle.rejectedAfterClose());
        System.out.println("challenge=PASS");
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
                return new QuerySummary(result, "NONE", identity.get(1, TimeUnit.SECONDS));
            } catch (ExecutionException ignored) {
                // TODO 1：从 ExecutionException 取出真实 cause 的类型与消息。
                return new QuerySummary(result, "UNKNOWN", identity.get(1, TimeUnit.SECONDS));
            }
        }
    }

    private static TimeoutCancel verifyTimeoutAndCancel() throws Exception {
        // TODO 2—4：用 latch 保证任务已启动；有上限地 get；超时后 cancel(true)；
        // 任务恢复中断并退出，随后再次 get 必须抛 CancellationException。
        return new TimeoutCancel(false, false);
    }

    private static Lifecycle verifyLifecycle() throws Exception {
        ExecutorService executor = Executors.newVirtualThreadPerTaskExecutor();
        // TODO 5：执行一个有上限的任务，关闭执行器并证明终止；关闭后提交必须被拒绝。
        executor.close();
        return new Lifecycle(executor.isTerminated(), false);
    }

    // 这些 import 和记录类型是可编辑脚手架，不是答案；不要用 sleep 或遗留后台线程绕过 oracle。
    @SuppressWarnings("unused")
    private static void contractVocabulary(
            CountDownLatch latch,
            TimeoutException timeout,
            CancellationException cancellation,
            RejectedExecutionException rejection) {
    }
}
