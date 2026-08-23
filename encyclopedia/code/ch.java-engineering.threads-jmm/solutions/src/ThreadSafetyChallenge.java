import java.lang.reflect.Method;
import java.lang.reflect.Modifier;
import java.util.ArrayList;
import java.util.List;
import java.util.Objects;

public final class ThreadSafetyChallenge {
    private static int assertions;

    private ThreadSafetyChallenge() {
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

    public static void main(String[] args) throws Exception {
        Method increment = ConcurrencySupport.SynchronizedCounter.class.getDeclaredMethod("increment");
        Method value = ConcurrencySupport.SynchronizedCounter.class.getDeclaredMethod("value");
        check(Modifier.isSynchronized(increment.getModifiers()), "increment synchronized");
        check(Modifier.isSynchronized(value.getModifiers()), "read synchronized");

        int sync = ConcurrencySupport.runTwoWorkers(new ConcurrencySupport.SynchronizedCounter(), 200);
        int locked = ConcurrencySupport.runTwoWorkers(new ConcurrencySupport.LockedCounter(), 200);
        int atomic = ConcurrencySupport.runTwoWorkers(new ConcurrencySupport.AtomicCounter(), 200);
        equal(400, sync, "sync count");
        equal(400, locked, "lock count");
        equal(400, atomic, "atomic count");

        for (int round = 0; round < 40; round++) {
            int actual = ConcurrencySupport.runTwoWorkers(
                    new ConcurrencySupport.SynchronizedCounter(), 200);
            if (actual != 400) {
                throw new AssertionError("round=" + round + " actual=" + actual);
            }
        }
        check(true, "40 synchronized rounds");
        for (int round = 0; round < 40; round++) {
            int actual = ConcurrencySupport.runTwoWorkers(new ConcurrencySupport.LockedCounter(), 200);
            if (actual != 400) {
                throw new AssertionError("lock round=" + round + " actual=" + actual);
            }
        }
        check(true, "40 lock rounds");

        Thread lifecycle = new Thread(() -> { }, "solution-worker");
        equal(Thread.State.NEW, lifecycle.getState(), "new");
        lifecycle.start();
        ConcurrencySupport.joinOrFail(lifecycle);
        equal(Thread.State.TERMINATED, lifecycle.getState(), "terminated");

        List<String> mutable = new ArrayList<>(List.of("WO-101", "WO-102"));
        List<String> snapshot = List.copyOf(mutable);
        mutable.add("WO-103");
        equal(List.of("WO-101", "WO-102"), snapshot, "snapshot");
        check(!lifecycle.isAlive(), "joined");
        equal("solution-worker", lifecycle.getName(), "name");

        System.out.println("PRIVATE SOLUTION PASS assertions=" + assertions + " rounds=40");
    }
}
