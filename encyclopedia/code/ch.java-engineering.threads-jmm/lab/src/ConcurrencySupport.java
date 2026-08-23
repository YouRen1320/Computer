import java.util.concurrent.CountDownLatch;
import java.util.concurrent.atomic.AtomicInteger;
import java.util.concurrent.locks.ReentrantLock;

public final class ConcurrencySupport {
    private static final long JOIN_TIMEOUT_MILLIS = 5_000;

    private ConcurrencySupport() {
    }

    interface Counter {
        void increment();

        int value();
    }

    static final class SynchronizedCounter implements Counter {
        private int value;

        @Override
        public synchronized void increment() {
            value++;
        }

        @Override
        public synchronized int value() {
            return value;
        }
    }

    static final class LockedCounter implements Counter {
        private final ReentrantLock lock = new ReentrantLock();
        private int value;

        @Override
        public void increment() {
            lock.lock();
            try {
                value++;
            } finally {
                lock.unlock();
            }
        }

        @Override
        public int value() {
            lock.lock();
            try {
                return value;
            } finally {
                lock.unlock();
            }
        }
    }

    static final class AtomicCounter implements Counter {
        private final AtomicInteger value = new AtomicInteger();

        @Override
        public void increment() {
            value.incrementAndGet();
        }

        @Override
        public int value() {
            return value.get();
        }
    }

    static int runTwoWorkers(Counter counter, int incrementsPerThread) throws InterruptedException {
        CountDownLatch ready = new CountDownLatch(2);
        CountDownLatch start = new CountDownLatch(1);
        Thread first = worker("counter-1", counter, incrementsPerThread, ready, start);
        Thread second = worker("counter-2", counter, incrementsPerThread, ready, start);
        first.start();
        second.start();
        ready.await();
        start.countDown();
        joinOrFail(first);
        joinOrFail(second);
        return counter.value();
    }

    static void joinOrFail(Thread thread) throws InterruptedException {
        thread.join(JOIN_TIMEOUT_MILLIS);
        if (thread.isAlive()) {
            thread.interrupt();
            throw new IllegalStateException("THREAD_DID_NOT_TERMINATE name=" + thread.getName());
        }
    }

    private static Thread worker(String name, Counter counter, int increments,
            CountDownLatch ready, CountDownLatch start) {
        return new Thread(() -> {
            ready.countDown();
            try {
                start.await();
            } catch (InterruptedException interrupted) {
                Thread.currentThread().interrupt();
                return;
            }
            for (int count = 0; count < increments; count++) {
                counter.increment();
            }
        }, name);
    }
}
