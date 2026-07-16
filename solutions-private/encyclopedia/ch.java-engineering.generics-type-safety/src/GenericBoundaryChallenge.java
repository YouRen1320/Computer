import java.util.ArrayList;
import java.util.List;

public final class GenericBoundaryChallenge {
    public static void main(String[] args) {
        int assertions = 0;
        Device device = new Device("PUMP-09");
        Result<Device> result = Result.success(device);
        Device selected = result.value();

        List<RepairTicket> source = List.of(
                new RepairTicket("WO-401"),
                new RepairTicket("WO-402"));
        List<WorkItem> workItems = new ArrayList<>();
        List<Object> auditItems = new ArrayList<>();
        copy(source, workItems);
        copy(source, auditItems);

        check("PUMP-09".equals(selected.id()), "typed result"); assertions++;
        check(selected == device, "result reference"); assertions++;
        check(source.size() == 2, "source size"); assertions++;
        check(workItems.size() == 2, "work size"); assertions++;
        check(auditItems.size() == 2, "audit size"); assertions++;
        check(workItems.get(0) == source.get(0), "work first"); assertions++;
        check(workItems.get(1) == source.get(1), "work second"); assertions++;
        check(auditItems.get(0) == source.get(0), "audit first"); assertions++;
        check("WO-401".equals(workItems.get(0).id()), "first id"); assertions++;
        check("WO-402".equals(workItems.get(1).id()), "second id"); assertions++;
        System.out.println("exercise.assertions=" + assertions + " passed");
    }

    static <T> void copy(List<? extends T> source, List<? super T> target) {
        for (T item : source) {
            target.add(item);
        }
    }

    static void check(boolean condition, String message) {
        if (!condition) {
            throw new AssertionError(message);
        }
    }

    record Result<T>(T value) {
        static <T> Result<T> success(T value) {
            return new Result<>(value);
        }
    }

    interface Identified { String id(); }
    interface WorkItem extends Identified { }
    record Device(String id) implements Identified { }
    record RepairTicket(String id) implements WorkItem { }
}
