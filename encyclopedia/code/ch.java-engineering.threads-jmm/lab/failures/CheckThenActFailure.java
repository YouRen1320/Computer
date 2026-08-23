import java.util.Collections;
import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.BrokenBarrierException;
import java.util.concurrent.CyclicBarrier;

public final class CheckThenActFailure {
    private CheckThenActFailure() {
    }

    public static void main(String[] args) throws Exception {
        List<String> ids = Collections.synchronizedList(new ArrayList<>());
        CyclicBarrier bothChecked = new CyclicBarrier(2);
        Runnable add = () -> {
            boolean absent = !ids.contains("WO-101");
            await(bothChecked);
            if (absent) {
                ids.add("WO-101");
            }
        };
        Thread first = new Thread(add, "check-act-1");
        Thread second = new Thread(add, "check-act-2");
        first.start();
        second.start();
        ConcurrencySupport.joinOrFail(first);
        ConcurrencySupport.joinOrFail(second);
        if (ids.size() != 1) {
            throw new IllegalStateException("CHECK_THEN_ACT_DUPLICATE size=" + ids.size());
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
