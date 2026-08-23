import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;
import java.util.stream.Collectors;

public final class SortingContractOracle {
    private SortingContractOracle() {
    }

    public static void main(String[] args) {
        int assertions = 0;
        List<SortingContractLab.WorkOrder> source = List.of(
                SortingContractLab.order("WO-105", 2, "2026-07-16T09:00", null),
                SortingContractLab.order("WO-103", 3, "2026-07-16T09:30", "2026-07-16T13:00"),
                SortingContractLab.order("WO-101", 3, "2026-07-16T09:00", "2026-07-16T11:00"),
                SortingContractLab.order("WO-102", 3, "2026-07-16T09:00", "2026-07-16T12:00"),
                SortingContractLab.order("WO-104", 2, "2026-07-16T08:00", "2026-07-16T10:00"),
                SortingContractLab.order("WO-106", 1, "2026-07-16T07:00", "2026-07-16T09:00"));
        List<SortingContractLab.WorkOrder> sorted = SortingContractLab.sortedCopy(
                source, SortingContractLab.DISPATCH_ORDER);
        check(ids(sorted).equals("WO-101,WO-102,WO-103,WO-104,WO-105,WO-106"), "dispatch order"); assertions++;
        check(ids(source).equals("WO-105,WO-103,WO-101,WO-102,WO-104,WO-106"), "source unchanged"); assertions++;
        check(sorted.getFirst().priority() == 3, "priority descending"); assertions++;
        check(sorted.get(0).createdAt().equals(sorted.get(1).createdAt()), "time tie"); assertions++;
        check(sorted.get(0).id().compareTo(sorted.get(1).id()) < 0, "id tie breaker"); assertions++;

        List<SortingContractLab.StableItem> stable = new ArrayList<>(List.of(
                new SortingContractLab.StableItem("A", 2),
                new SortingContractLab.StableItem("B", 1),
                new SortingContractLab.StableItem("C", 2),
                new SortingContractLab.StableItem("D", 1)));
        Comparator<SortingContractLab.StableItem> byPriorityOnly = Comparator
                .comparingInt(SortingContractLab.StableItem::priority).reversed();
        stable.sort(byPriorityOnly);
        check(stable.stream().map(SortingContractLab.StableItem::id).toList()
                .equals(List.of("A", "C", "B", "D")), "stable groups"); assertions++;
        check(byPriorityOnly.compare(stable.get(0), stable.get(1)) == 0, "stable equality"); assertions++;

        List<SortingContractLab.WorkOrder> due = new ArrayList<>(List.of(
                SortingContractLab.order("WO-202", 1, "2026-07-16T08:00", null),
                SortingContractLab.order("WO-203", 1, "2026-07-16T08:00", "2026-07-16T10:00"),
                SortingContractLab.order("WO-201", 1, "2026-07-16T08:00", "2026-07-16T09:00")));
        Comparator<SortingContractLab.WorkOrder> byDue = Comparator.comparing(
                SortingContractLab.WorkOrder::dueAt,
                Comparator.nullsLast(Comparator.naturalOrder()));
        due.sort(byDue.thenComparing(SortingContractLab.WorkOrder::id));
        check(ids(due).equals("WO-201,WO-203,WO-202"), "null field last"); assertions++;
        check(due.getLast().dueAt() == null, "null is last"); assertions++;

        List<SortingContractLab.WorkOrder> withNullObject = new ArrayList<>();
        withNullObject.add(source.get(0));
        withNullObject.add(null);
        withNullObject.add(source.get(1));
        withNullObject.sort(Comparator.nullsLast(SortingContractLab.DISPATCH_ORDER));
        check(withNullObject.getLast() == null, "null object last"); assertions++;

        List<SortingContractLab.DeviceId> deviceIds = new ArrayList<>(List.of(
                new SortingContractLab.DeviceId("PUMP-01"),
                new SortingContractLab.DeviceId("FAN-02")));
        deviceIds.sort(Comparator.naturalOrder());
        check(deviceIds.getFirst().value().equals("FAN-02"), "natural order"); assertions++;
        check(SortingContractLab.DISPATCH_ORDER.compare(source.get(0), source.get(0)) == 0, "self compare"); assertions++;
        int forward = Integer.signum(SortingContractLab.DISPATCH_ORDER.compare(source.get(0), source.get(1)));
        int reverse = Integer.signum(SortingContractLab.DISPATCH_ORDER.compare(source.get(1), source.get(0)));
        check(forward == -reverse, "sign reverse"); assertions++;
        check(SortingContractLab.DISPATCH_ORDER.compare(source.get(1), source.get(2)) > 0, "time order"); assertions++;
        check(SortingContractLab.DISPATCH_ORDER.compare(source.get(2), source.get(3)) < 0, "id order"); assertions++;
        check(SortingContractLab.DISPATCH_ORDER.compare(source.get(2), source.get(3)) != 0, "total tie breaker"); assertions++;
        expectUnsupported(() -> sorted.add(source.get(0))); assertions++;
        check(source.size() == 6, "source size"); assertions++;

        verifyContract(source, SortingContractLab.DISPATCH_ORDER);

        System.out.println("report.dispatch=" + ids(sorted));
        System.out.println("report.stable=" + stable.stream()
                .map(SortingContractLab.StableItem::id).collect(Collectors.joining(",")));
        System.out.println("report.nullsLast=" + ids(due));
        System.out.println("report.contract=elements:6,pairs:36,triples:216");
        System.out.println("assertions=" + assertions + " passed");
    }

    private static void verifyContract(
            List<SortingContractLab.WorkOrder> values,
            Comparator<SortingContractLab.WorkOrder> comparator) {
        for (SortingContractLab.WorkOrder x : values) {
            check(comparator.compare(x, x) == 0, "contract self");
            for (SortingContractLab.WorkOrder y : values) {
                int xy = Integer.signum(comparator.compare(x, y));
                int yx = Integer.signum(comparator.compare(y, x));
                check(xy == -yx, "contract sign symmetry");
                for (SortingContractLab.WorkOrder z : values) {
                    int yz = Integer.signum(comparator.compare(y, z));
                    int xz = Integer.signum(comparator.compare(x, z));
                    if (xy > 0 && yz > 0) {
                        check(xz > 0, "contract transitivity");
                    }
                    if (xy == 0) {
                        check(xz == yz, "contract zero equivalence");
                    }
                }
            }
        }
    }

    private static String ids(List<SortingContractLab.WorkOrder> orders) {
        return orders.stream().map(SortingContractLab.WorkOrder::id)
                .collect(Collectors.joining(","));
    }

    private static void expectUnsupported(Runnable action) {
        try {
            action.run();
            throw new AssertionError("expected UnsupportedOperationException");
        } catch (UnsupportedOperationException expected) {
            // The stable oracle is the exception type, not its message.
        }
    }

    private static void check(boolean condition, String message) {
        if (!condition) {
            throw new AssertionError(message);
        }
    }
}
