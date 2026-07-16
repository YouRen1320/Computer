import java.util.ArrayList;
import java.util.List;

public final class GenericTypeDemo {
    public static void main(String[] args) {
        Device device = new Device("PUMP-01");
        Result<Device> result = Result.success(device);

        List<RepairTicket> source = List.of(
                new RepairTicket("WO-101"),
                new RepairTicket("WO-102"));
        List<WorkItem> workItems = new ArrayList<>();
        List<Object> auditItems = new ArrayList<>();
        copy(source, workItems);
        copy(source, auditItems);

        System.out.println("result.type=Device");
        System.out.println("result.id=" + result.value().id());
        System.out.println("workItems.size=" + workItems.size());
        System.out.println("workItems.first=" + workItems.getFirst().id());
        System.out.println("auditItems.size=" + auditItems.size());
        System.out.println("same.reference=" + (source.getFirst() == workItems.getFirst()));
    }

    static <T> void copy(List<? extends T> source, List<? super T> target) {
        for (T item : source) {
            target.add(item);
        }
    }

    record Result<T>(T value) {
        static <T> Result<T> success(T value) {
            return new Result<>(value);
        }
    }

    interface Identified {
        String id();
    }

    record Device(String id) implements Identified {
    }

    interface WorkItem extends Identified {
    }

    record RepairTicket(String id) implements WorkItem {
    }
}
