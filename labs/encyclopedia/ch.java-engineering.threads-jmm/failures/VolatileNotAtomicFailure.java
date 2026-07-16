import java.util.concurrent.BrokenBarrierException;
import java.util.concurrent.CyclicBarrier;

public final class VolatileNotAtomicFailure {
    private VolatileNotAtomicFailure() {
    }

    private static final class Counter {
        volatile int value;
    }

    public static void main(String[] args) throws Exception {
        Counter counter = new Counter();
        CyclicBarrier bothRead = new CyclicBarrier(2);
        Runnable increment = () -> {
            int observed = counter.value;
            await(bothRead);
            counter.value = observed + 1;
        };
        Thread first = new Thread(increment, "volatile-1");
        Thread second = new Thread(increment, "volatile-2");
        first.start();
        second.start();
        ConcurrencySupport.joinOrFail(first);
        ConcurrencySupport.joinOrFail(second);
        if (counter.value != 2) {
            throw new IllegalStateException("VOLATILE_NOT_ATOMIC expected=2 actual=" + counter.value);
        }
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
