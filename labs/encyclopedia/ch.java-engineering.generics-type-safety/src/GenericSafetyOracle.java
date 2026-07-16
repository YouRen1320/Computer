import java.util.ArrayList;
import java.util.List;

public final class GenericSafetyOracle {
    public static void main(String[] args) {
        int assertions = 0;
        var device = new GenericSafetyLab.Device("PUMP-01");
        GenericSafetyLab.Result<GenericSafetyLab.Device> result = GenericSafetyLab.Result.success(device);

        List<GenericSafetyLab.RepairTicket> source = List.of(
                new GenericSafetyLab.RepairTicket("WO-201"),
                new GenericSafetyLab.RepairTicket("WO-202"));
        List<GenericSafetyLab.WorkItem> workItems = new ArrayList<>();
        List<Object> auditItems = new ArrayList<>();
        GenericSafetyLab.copy(source, workItems);
        GenericSafetyLab.copy(source, auditItems);

        check(result.value() == device, "result reference"); assertions++;
        check("PUMP-01".equals(result.value().id()), "result type"); assertions++;
        check(source.size() == 2, "source size"); assertions++;
        check(workItems.size() == 2, "work target size"); assertions++;
        check(workItems.get(0) == source.get(0), "first reference"); assertions++;
        check(workItems.get(1) == source.get(1), "second reference"); assertions++;
        check(auditItems.size() == 2, "object target size"); assertions++;
        check(auditItems.get(0) instanceof GenericSafetyLab.RepairTicket, "audit runtime item"); assertions++;
        workItems.add(new GenericSafetyLab.InspectionTicket("IN-301"));
        check(workItems.size() == 3, "consumer accepts sibling subtype"); assertions++;
        check("IN-301".equals(workItems.get(2).id()), "sibling id"); assertions++;
        check(source.size() == 2, "source unchanged"); assertions++;
        check(auditItems.get(1) == source.get(1), "audit second reference"); assertions++;

        System.out.println("report.input=RepairTicket[WO-201,WO-202]");
        System.out.println("report.operation=copy extends-to-super");
        System.out.println("report.result=WorkItem[WO-201,WO-202,IN-301]");
        System.out.println("assertions=" + assertions + " passed");
    }

    private static void check(boolean condition, String message) {
        if (!condition) {
            throw new AssertionError(message);
        }
    }
}
