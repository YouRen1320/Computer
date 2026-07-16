import java.lang.reflect.Method;
import java.lang.reflect.Modifier;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.locks.ReentrantLock;

public final class ThreadSafetyChallenge {
    private ThreadSafetyChallenge() {
    }

    interface Counter {
        void increment();

        int value();
    }

    static final class SynchronizedCounter implements Counter {
        private int value;

        @Override
        public void increment() {
            // TODO 1: protect the full read-modify-write with the instance monitor.
            value++;
        }

        @Override
        public int value() {
            // TODO 2: read under the same monitor.
            return value;
        }
    }

    static final class LockedCounter implements Counter {
        private final ReentrantLock lock = new ReentrantLock();
        private int value;

        @Override
        public void increment() {
            // TODO 3: lock, immediately enter try, mutate, and unlock in finally.
            mutateOnlyWhenLocked();
        }

        @Override
        public int value() {
            // TODO 4: read using the same final lock and try/finally.
            return readOnlyWhenLocked();
        }

        private void mutateOnlyWhenLocked() {
            if (!lock.isHeldByCurrentThread()) {
                throw new IllegalStateException("LOCK_NOT_HELD");
            }
            value++;
        }

        private int readOnlyWhenLocked() {
            if (!lock.isHeldByCurrentThread()) {
                throw new IllegalStateException("LOCK_NOT_HELD");
            }
            return value;
        }
    }

    public static void main(String[] args) throws Exception {
        try {
            Method increment = SynchronizedCounter.class.getDeclaredMethod("increment");
            Method value = SynchronizedCounter.class.getDeclaredMethod("value");
            if (!Modifier.isSynchronized(increment.getModifiers())
                    || !Modifier.isSynchronized(value.getModifiers())) {
                throw new IllegalStateException("MONITOR_NOT_SHARED");
            }
            int synchronizedCount = run(new SynchronizedCounter());
            int lockedCount = run(new LockedCounter());
            if (synchronizedCount != 400 || lockedCount != 400) {
                throw new IllegalStateException("COUNT_MISMATCH");
            }
        } catch (RuntimeException failure) {
            throw new IllegalStateException("COUNTER_CONTRACT complete TODO 1..4", failure);
        }
        System.out.println("CHALLENGE PASS assertions=4");
    }

    private static int run(Counter counter) throws InterruptedException {
        CountDownLatch ready = new CountDownLatch(2);
        CountDownLatch start = new CountDownLatch(1);
        Runnable task = () -> {
            ready.countDown();
            try {
                start.await();
            } catch (InterruptedException interrupted) {
                Thread.currentThread().interrupt();
                return;
            }
            for (int count = 0; count < 200; count++) {
                counter.increment();
            }
        };
        Thread first = new Thread(task, "challenge-1");
        Thread second = new Thread(task, "challenge-2");
        first.start();
        second.start();
        ready.await();
        start.countDown();
        first.join(5_000);
        second.join(5_000);
        if (first.isAlive() || second.isAlive()) {
            throw new IllegalStateException("THREAD_DID_NOT_TERMINATE");
        }
        return counter.value();
    }
}
