import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.atomic.AtomicReference;

public final class ThreadsJmmDemo {
    private ThreadsJmmDemo() {
    }

    public static void main(String[] args) throws Exception {
        String config = "config-v1";
        AtomicReference<String> seenConfig = new AtomicReference<>();
        AtomicReference<String> result = new AtomicReference<>();
        Thread lifecycle = new Thread(() -> {
            seenConfig.set(config);
            result.set("result-42");
        }, "lifecycle-worker");

        System.out.println("lifecycle.before=" + lifecycle.getState());
        lifecycle.start();
        ConcurrencySupport.joinOrFail(lifecycle);
        System.out.println("lifecycle.after=" + lifecycle.getState());
        System.out.println("start.happensBefore=" + seenConfig.get());
        System.out.println("join.happensBefore=" + result.get());

        int synchronizedCount = ConcurrencySupport.runTwoWorkers(
                new ConcurrencySupport.SynchronizedCounter(), 200);
        int lockedCount = ConcurrencySupport.runTwoWorkers(
                new ConcurrencySupport.LockedCounter(), 200);
        int atomicCount = ConcurrencySupport.runTwoWorkers(
                new ConcurrencySupport.AtomicCounter(), 200);
        System.out.println("synchronized.count=" + synchronizedCount);
        System.out.println("lock.count=" + lockedCount);
        System.out.println("atomic.count=" + atomicCount);

        List<String> builder = new ArrayList<>(List.of("WO-101", "WO-102"));
        List<String> snapshot = List.copyOf(builder);
        builder.add("WO-103");
        AtomicReference<String> observedSnapshot = new AtomicReference<>();
        Thread reader = new Thread(
                () -> observedSnapshot.set(String.join(",", snapshot)),
                "snapshot-reader");
        reader.start();
        ConcurrencySupport.joinOrFail(reader);
        System.out.println("immutable.snapshot=" + observedSnapshot.get());
    }
}
