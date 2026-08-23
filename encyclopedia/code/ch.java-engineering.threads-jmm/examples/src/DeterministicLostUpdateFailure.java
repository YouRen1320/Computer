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
        Thread first = new Thread(() -> incrementInTwoPhases(counter, bothRead), "lost-update-1");
        Thread second = new Thread(() -> incrementInTwoPhases(counter, bothRead), "lost-update-2");
        first.start();
        second.start();
        ConcurrencySupport.joinOrFail(first);
        ConcurrencySupport.joinOrFail(second);
        if (counter.value != 2) {
            throw new IllegalStateException("LOST_UPDATE expected=2 actual=" + counter.value);
        }
    }

    private static void incrementInTwoPhases(Counter counter, CyclicBarrier bothRead) {
        int observed = counter.value;
        try {
            bothRead.await();
        } catch (InterruptedException interrupted) {
            Thread.currentThread().interrupt();
            return;
        } catch (BrokenBarrierException broken) {
            throw new IllegalStateException("barrier broken", broken);
        }
        counter.value = observed + 1;
    }
}
