import java.util.List;

final class GenericSafetyLab {
    private GenericSafetyLab() {
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

    interface WorkItem extends Identified {
    }

    record Device(String id) implements Identified {
    }

    record RepairTicket(String id) implements WorkItem {
    }

    record InspectionTicket(String id) implements WorkItem {
    }
}
