import java.util.concurrent.BrokenBarrierException;
import java.util.concurrent.CyclicBarrier;

public final class DeterministicLostUpdateContractFailure {
    private DeterministicLostUpdateContractFailure() {
    }

    private static final class Counter {
        int value;
    }

    public static void main(String[] args) throws Exception {
        Counter counter = new Counter();
        CyclicBarrier bothRead = new CyclicBarrier(2);
        Runnable task = () -> {
            int observed = counter.value;
            try {
                bothRead.await();
            } catch (InterruptedException interrupted) {
                Thread.currentThread().interrupt();
                return;
            } catch (BrokenBarrierException broken) {
                throw new IllegalStateException("barrier", broken);
            }
            counter.value = observed + 1;
        };
        Thread first = new Thread(task);
        Thread second = new Thread(task);
        first.start();
        second.start();
        ConcurrencySupport.joinOrFail(first);
        ConcurrencySupport.joinOrFail(second);
        if (counter.value != 2) {
            throw new IllegalStateException("LOST_UPDATE expected=2 actual=" + counter.value);
        }
    }
}
