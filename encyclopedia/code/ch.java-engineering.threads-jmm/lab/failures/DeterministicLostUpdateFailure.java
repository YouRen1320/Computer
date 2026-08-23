import java.util.concurrent.BrokenBarrierException;
import java.util.concurrent.CyclicBarrier;

public final class DeterministicLostUpdateFailure {
    private DeterministicLostUpdateFailure() {
    }

    private static final class Counter {
        int value;
    }

    public static void main(String[] args) throws Exception {
        Counter counter = new Counter();
        CyclicBarrier bothRead = new CyclicBarrier(2);
        Thread first = worker(counter, bothRead, "lost-1");
        Thread second = worker(counter, bothRead, "lost-2");
        first.start();
        second.start();
        ConcurrencySupport.joinOrFail(first);
        ConcurrencySupport.joinOrFail(second);
        if (counter.value != 2) {
            throw new IllegalStateException("LOST_UPDATE expected=2 actual=" + counter.value);
        }
    }

    private static Thread worker(Counter counter, CyclicBarrier barrier, String name) {
        return new Thread(() -> {
            int observed = counter.value;
            await(barrier);
            counter.value = observed + 1;
        }, name);
    }

    private static void await(CyclicBarrier barrier) {
        try {
            barrier.await();
        } catch (InterruptedException interrupted) {
            Thread.currentThread().interrupt();
        } catch (BrokenBarrierException broken) {
            throw new IllegalStateException("barrier broken", broken);
        }
    }
}
