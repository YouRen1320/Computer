import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.CancellationException;
import java.util.concurrent.CopyOnWriteArrayList;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.CyclicBarrier;
import java.util.concurrent.ExecutionException;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;
import java.util.concurrent.RejectedExecutionException;
import java.util.concurrent.Semaphore;
import java.util.concurrent.ThreadFactory;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.TimeoutException;
import java.util.concurrent.atomic.AtomicInteger;

/** Deterministic FactoryCare oracle for success, failure, timeout, cancellation, and shutdown. */
public final class ExecutorLifecycleOracle {
    private record BasicEvidence(String success, String failureCause, boolean rejectedAfterShutdown, int liveWorkers) {}

    private record CancelEvidence(boolean timedOut, boolean cancelled, boolean interruptObserved) {}

    private record IgnoredInterruptEvidence(boolean cancelled, boolean terminatedBeforeRelease, boolean terminatedAfterRelease) {}

    private record VirtualEvidence(int tasks, boolean allVirtual, int maxResourceUse, int lostUpdate, int atomicCount) {}

    public static void main(String[] args) throws Exception {
        BasicEvidence basic = verifySuccessFailureAndShutdown();
        CancelEvidence cooperative = verifyTimeoutAndCooperativeCancellation();
        IgnoredInterruptEvidence ignored = verifyIgnoredInterruptBoundary();
        VirtualEvidence virtual = verifyVirtualThreadsResourceGateAndSharedState();

        System.out.println("success-result=" + basic.success());
        System.out.println("failure-cause=" + basic.failureCause());
        System.out.println("shutdown-rejects=" + basic.rejectedAfterShutdown() + ",workers-alive=" + basic.liveWorkers());
        System.out.println("timeout-observed=" + cooperative.timedOut()
                + ",cancelled=" + cooperative.cancelled()
                + ",interrupt-observed=" + cooperative.interruptObserved());
        System.out.println("ignored-interrupt-cancelled=" + ignored.cancelled()
                + ",terminated-before-release=" + ignored.terminatedBeforeRelease()
                + ",terminated-after-release=" + ignored.terminatedAfterRelease());
        System.out.println("virtual-tasks=" + virtual.tasks()
                + ",all-virtual=" + virtual.allVirtual()
                + ",max-resource-use=" + virtual.maxResourceUse());
        System.out.println("virtual-shared-race=" + virtual.lostUpdate() + ",atomic=" + virtual.atomicCount());
        System.out.println("executor-lifecycle-oracle=PASS");
    }

    private static BasicEvidence verifySuccessFailureAndShutdown() throws Exception {
        List<Thread> workers = new CopyOnWriteArrayList<>();
        ThreadFactory baseFactory = Thread.ofPlatform().name("fc-lab-worker-", 0).factory();
        ThreadFactory recordingFactory = task -> {
            Thread worker = baseFactory.newThread(task);
            workers.add(worker);
            return worker;
        };
        ExecutorService executor = Executors.newFixedThreadPool(2, recordingFactory);
        String successValue;
        String failureCause;
        try {
            Future<String> success = executor.submit(() -> "WO-201:READY");
            Future<String> failure = executor.submit(() -> {
                throw new IllegalArgumentException("unknown-device");
            });
            successValue = success.get(2, TimeUnit.SECONDS);
            try {
                failure.get(2, TimeUnit.SECONDS);
                throw new AssertionError("failure task unexpectedly returned");
            } catch (ExecutionException expected) {
                Throwable cause = expected.getCause();
                failureCause = cause.getClass().getSimpleName() + ":" + cause.getMessage();
            }
        } finally {
            shutdownAndAwait(executor);
        }

        boolean rejected = false;
        try {
            executor.submit(() -> "too-late");
        } catch (RejectedExecutionException expected) {
            rejected = true;
        }
        int liveWorkers = (int) workers.stream().filter(Thread::isAlive).count();
        check(executor.isShutdown(), "executor must report shutdown");
        check(executor.isTerminated(), "executor must report termination");
        check(rejected, "submission after shutdown must be rejected");
        check(liveWorkers == 0, "no recorded worker may remain alive");
        return new BasicEvidence(successValue, failureCause, rejected, liveWorkers);
    }

    private static CancelEvidence verifyTimeoutAndCooperativeCancellation() throws Exception {
        ExecutorService executor = Executors.newSingleThreadExecutor();
        CountDownLatch started = new CountDownLatch(1);
        CountDownLatch release = new CountDownLatch(1);
        CountDownLatch finished = new CountDownLatch(1);
        CountDownLatch interruptObserved = new CountDownLatch(1);
        Future<String> future = executor.submit(() -> {
            started.countDown();
            try {
                release.await();
                return "released";
            } catch (InterruptedException interrupted) {
                interruptObserved.countDown();
                Thread.currentThread().interrupt();
                return "interrupted";
            } finally {
                finished.countDown();
            }
        });
        try {
            await(started, "cooperative task did not start");
            boolean timedOut = false;
            try {
                future.get(40, TimeUnit.MILLISECONDS);
            } catch (TimeoutException expected) {
                timedOut = true;
            }
            boolean cancelRequested = future.cancel(true);
            release.countDown();
            await(interruptObserved, "cooperative task did not observe interruption");
            await(finished, "cooperative task did not finish");
            boolean cancellationVisible = false;
            try {
                future.get();
            } catch (CancellationException expected) {
                cancellationVisible = true;
            }
            shutdownAndAwait(executor);

            check(timedOut, "bounded get must time out while latch is closed");
            check(cancelRequested && future.isCancelled(), "Future must report cancellation");
            check(cancellationVisible, "get after cancellation must throw CancellationException");
            return new CancelEvidence(timedOut, future.isCancelled(), interruptObserved.getCount() == 0);
        } finally {
            release.countDown();
            forceShutdown(executor);
        }
    }

    private static IgnoredInterruptEvidence verifyIgnoredInterruptBoundary() throws Exception {
        ExecutorService executor = Executors.newSingleThreadExecutor();
        CountDownLatch started = new CountDownLatch(1);
        CountDownLatch interruptIgnored = new CountDownLatch(1);
        CountDownLatch release = new CountDownLatch(1);
        CountDownLatch finished = new CountDownLatch(1);
        Future<Void> future = executor.submit(() -> {
            started.countDown();
            try {
                release.await();
            } catch (InterruptedException intentionallyIgnored) {
                interruptIgnored.countDown();
                release.await();
            } finally {
                finished.countDown();
            }
            return null;
        });

        try {
            await(started, "ignore-interrupt task did not start");
            boolean cancelled = future.cancel(true);
            await(interruptIgnored, "task did not receive the interrupt request");
            executor.shutdown();
            boolean terminatedBeforeRelease = executor.awaitTermination(40, TimeUnit.MILLISECONDS);
            release.countDown();
            await(finished, "ignored-interrupt task did not finish after explicit release");
            boolean terminatedAfterRelease = executor.awaitTermination(2, TimeUnit.SECONDS);

            check(cancelled && future.isCancelled(), "Future must be cancelled");
            check(!terminatedBeforeRelease, "cancelled Future must not be mistaken for stopped task");
            check(terminatedAfterRelease, "executor must terminate after the task is explicitly released");
            return new IgnoredInterruptEvidence(cancelled, terminatedBeforeRelease, terminatedAfterRelease);
        } finally {
            release.countDown();
            forceShutdown(executor);
        }
    }

    private static VirtualEvidence verifyVirtualThreadsResourceGateAndSharedState() throws Exception {
        int taskCount = 6;
        Semaphore resourceSlots = new Semaphore(2);
        AtomicInteger activeResources = new AtomicInteger();
        AtomicInteger maxResources = new AtomicInteger();
        CountDownLatch twoInside = new CountDownLatch(2);
        CountDownLatch release = new CountDownLatch(1);
        List<Future<Boolean>> futures = new ArrayList<>();
        ExecutorService virtualExecutor = Executors.newVirtualThreadPerTaskExecutor();
        try (virtualExecutor) {
            try {
                for (int i = 0; i < taskCount; i++) {
                    futures.add(virtualExecutor.submit(() -> {
                        resourceSlots.acquire();
                        int current = activeResources.incrementAndGet();
                        maxResources.accumulateAndGet(current, Math::max);
                        twoInside.countDown();
                        try {
                            release.await();
                            return Thread.currentThread().isVirtual();
                        } finally {
                            activeResources.decrementAndGet();
                            resourceSlots.release();
                        }
                    }));
                }
                await(twoInside, "two virtual tasks did not enter the resource gate");
                check(maxResources.get() == 2, "resource gate must cap concurrent use at two");
                release.countDown();
                for (Future<Boolean> future : futures) {
                    check(future.get(2, TimeUnit.SECONDS), "task must run in a virtual thread");
                }
            } finally {
                release.countDown();
                futures.forEach(future -> future.cancel(true));
            }
        }
        check(virtualExecutor.isTerminated(), "virtual executor close must wait for completion");

        int[] unsafeCounter = {0};
        CyclicBarrier bothRead = new CyclicBarrier(2);
        AtomicInteger safeCounter = new AtomicInteger();
        try (ExecutorService executor = Executors.newVirtualThreadPerTaskExecutor()) {
            Future<Void> first = executor.submit(() -> lostUpdate(unsafeCounter, bothRead));
            Future<Void> second = executor.submit(() -> lostUpdate(unsafeCounter, bothRead));
            first.get(2, TimeUnit.SECONDS);
            second.get(2, TimeUnit.SECONDS);
            Future<?> safeFirst = executor.submit(safeCounter::incrementAndGet);
            Future<?> safeSecond = executor.submit(safeCounter::incrementAndGet);
            safeFirst.get(2, TimeUnit.SECONDS);
            safeSecond.get(2, TimeUnit.SECONDS);
        }
        check(unsafeCounter[0] == 1, "barrier must deterministically expose the lost update");
        check(safeCounter.get() == 2, "atomic counter must preserve both updates");
        return new VirtualEvidence(taskCount, true, maxResources.get(), unsafeCounter[0], safeCounter.get());
    }

    private static Void lostUpdate(int[] counter, CyclicBarrier bothRead) throws Exception {
        int observed = counter[0];
        bothRead.await(2, TimeUnit.SECONDS);
        counter[0] = observed + 1;
        return null;
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
                throw new AssertionError("executor did not terminate after shutdownNow");
            }
        }
    }

    private static void forceShutdown(ExecutorService executor) throws InterruptedException {
        if (executor.isTerminated()) {
            return;
        }
        executor.shutdownNow();
        if (!executor.awaitTermination(2, TimeUnit.SECONDS)) {
            throw new AssertionError("executor did not terminate during cleanup");
        }
    }

    private static void check(boolean condition, String message) {
        if (!condition) {
            throw new AssertionError(message);
        }
    }
}
