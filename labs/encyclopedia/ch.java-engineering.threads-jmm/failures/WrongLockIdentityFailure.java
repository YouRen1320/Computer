import java.util.concurrent.BrokenBarrierException;
import java.util.concurrent.CyclicBarrier;

public final class WrongLockIdentityFailure {
    private WrongLockIdentityFailure() {
    }

    private static final class Counter {
        int value;
    }

    public static void main(String[] args) throws Exception {
        Counter counter = new Counter();
        CyclicBarrier bothRead = new CyclicBarrier(2);
        Thread first = worker(counter, new Object(), bothRead, "wrong-lock-1");
        Thread second = worker(counter, new Object(), bothRead, "wrong-lock-2");
        first.start();
        second.start();
        ConcurrencySupport.joinOrFail(first);
        ConcurrencySupport.joinOrFail(second);
        if (counter.value != 2) {
            throw new IllegalStateException("WRONG_LOCK_IDENTITY expected=2 actual=" + counter.value);
        }
    }

    private static Thread worker(Counter counter, Object lock, CyclicBarrier barrier, String name) {
        return new Thread(() -> {
            synchronized (lock) {
                int observed = counter.value;
                await(barrier);
                counter.value = observed + 1;
            }
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
