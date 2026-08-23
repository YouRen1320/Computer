import java.util.ArrayList;
import java.util.List;
import java.util.Objects;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.atomic.AtomicInteger;
import java.util.concurrent.atomic.AtomicReference;
import java.util.function.Supplier;

public final class ThreadsJmmOracle {
    private static final int ROUNDS = 40;
    private static final int INCREMENTS = 200;
    private static int assertions;

    private ThreadsJmmOracle() {
    }

    private static void check(boolean condition, String name) {
        assertions++;
        if (!condition) {
            throw new AssertionError(name);
        }
    }

    private static void equal(Object expected, Object actual, String name) {
        check(Objects.equals(expected, actual), name + " expected=" + expected + " actual=" + actual);
    }

    private static int verifyRounds(Supplier<ConcurrencySupport.Counter> factory) throws InterruptedException {
        for (int round = 0; round < ROUNDS; round++) {
            int actual = ConcurrencySupport.runTwoWorkers(factory.get(), INCREMENTS);
            if (actual != INCREMENTS * 2) {
                throw new AssertionError("round=" + round + " expected=400 actual=" + actual);
            }
        }
        return ROUNDS;
    }

    private static final class VolatileSignal {
        private volatile boolean ready;
        private int data;
    }

    public static void main(String[] args) throws Exception {
        String config = "config-v1";
        AtomicReference<String> seen = new AtomicReference<>();
        AtomicInteger result = new AtomicInteger();
        Thread lifecycle = new Thread(() -> {
            seen.set(config);
            result.set(42);
        }, "lifecycle-worker");
        equal(Thread.State.NEW, lifecycle.getState(), "new state");
        lifecycle.start();
        ConcurrencySupport.joinOrFail(lifecycle);
        equal("config-v1", seen.get(), "start edge");
        equal(42, result.get(), "join result");
        equal(Thread.State.TERMINATED, lifecycle.getState(), "terminated state");
        check(!lifecycle.isAlive(), "not alive");

        equal(ROUNDS, verifyRounds(ConcurrencySupport.SynchronizedCounter::new),
                "synchronized rounds");
        equal(ROUNDS, verifyRounds(ConcurrencySupport.LockedCounter::new), "lock rounds");
        equal(ROUNDS, verifyRounds(ConcurrencySupport.AtomicCounter::new), "atomic rounds");
        int sync = ConcurrencySupport.runTwoWorkers(new ConcurrencySupport.SynchronizedCounter(), INCREMENTS);
        int locked = ConcurrencySupport.runTwoWorkers(new ConcurrencySupport.LockedCounter(), INCREMENTS);
        int atomic = ConcurrencySupport.runTwoWorkers(new ConcurrencySupport.AtomicCounter(), INCREMENTS);
        equal(400, sync, "synchronized sample");
        equal(400, locked, "lock sample");
        equal(400, atomic, "atomic sample");

        List<String> mutable = new ArrayList<>(List.of("WO-101", "WO-102"));
        List<String> snapshot = List.copyOf(mutable);
        mutable.add("WO-103");
        equal(2, snapshot.size(), "snapshot size");
        equal(List.of("WO-101", "WO-102"), snapshot, "snapshot content");

        VolatileSignal signal = new VolatileSignal();
        AtomicInteger volatileObserved = new AtomicInteger();
        CountDownLatch spinning = new CountDownLatch(1);
        Thread volatileReader = new Thread(() -> {
            spinning.countDown();
            while (!signal.ready) {
                Thread.onSpinWait();
            }
            volatileObserved.set(signal.data);
        }, "volatile-reader");
        volatileReader.start();
        spinning.await();
        signal.data = 7;
        signal.ready = true;
        ConcurrencySupport.joinOrFail(volatileReader);
        equal(7, volatileObserved.get(), "volatile publication");
        check(!volatileReader.isAlive(), "volatile reader terminated");

        CountDownLatch published = new CountDownLatch(1);
        AtomicInteger latchValue = new AtomicInteger();
        Thread publisher = new Thread(() -> {
            latchValue.set(9);
            published.countDown();
        }, "latch-publisher");
        publisher.start();
        published.await();
        equal(9, latchValue.get(), "latch edge");
        ConcurrencySupport.joinOrFail(publisher);

        List<String> ids = new ArrayList<>();
        Object idsLock = new Object();
        AtomicInteger added = new AtomicInteger();
        Runnable addOnce = () -> {
            synchronized (idsLock) {
                if (!ids.contains("WO-101")) {
                    ids.add("WO-101");
                    added.incrementAndGet();
                }
            }
        };
        Thread addFirst = new Thread(addOnce, "add-1");
        Thread addSecond = new Thread(addOnce, "add-2");
        addFirst.start();
        addSecond.start();
        ConcurrencySupport.joinOrFail(addFirst);
        ConcurrencySupport.joinOrFail(addSecond);
        equal(List.of("WO-101"), ids, "atomic check then act");
        equal(1, added.get(), "added once");

        boolean secondStartRejected = false;
        try {
            lifecycle.start();
        } catch (IllegalThreadStateException expected) {
            secondStartRejected = true;
        }
        check(secondStartRejected, "thread starts once");
        equal("lifecycle-worker", lifecycle.getName(), "thread name");

        System.out.println("report.lifecycle=NEW->TERMINATED");
        System.out.println("report.happensBefore=start:" + seen.get() + ",join:" + result.get()
                + ",latch:" + latchValue.get());
        System.out.println("report.counters=rounds:40,incrementsPerThread:200,expected:400");
        System.out.println("report.strategies=synchronized:" + sync + ",lock:" + locked
                + ",atomic:" + atomic);
        System.out.println("report.visibility=volatile:" + volatileObserved.get()
                + ",terminated:" + !volatileReader.isAlive());
        System.out.println("assertions=" + assertions + " passed");
    }
}
