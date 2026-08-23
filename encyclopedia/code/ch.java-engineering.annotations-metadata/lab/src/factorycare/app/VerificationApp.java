package factorycare.app;

import factorycare.generated.RoleIndex;
import factorycare.metadata.ClassAudit;
import factorycare.metadata.CompileReport;
import factorycare.metadata.RequiresRole;
import java.util.List;

public final class VerificationApp {
    private VerificationApp() {
    }

    public static void main(String[] args) {
        List<String> entries = RoleIndex.entries();
        RequiresRole[] direct = WorkOrderPolicy.class.getAnnotationsByType(RequiresRole.class);
        RequiresRole[] inherited = UrgentWorkOrderPolicy.class.getAnnotationsByType(RequiresRole.class);

        require(RoleIndex.sourceSeen(), "SOURCE annotation must be visible to the processor");
        require(entries.equals(List.of(
                "factorycare.app.WorkOrderPolicy#ADMIN@TENANT",
                "factorycare.app.WorkOrderPolicy#DISPATCHER@REGION")), "generated index");
        require(direct.length == 2, "runtime repeatable roles");
        require(inherited.length == 2, "inherited class roles");
        require(!WorkOrderPolicy.class.isAnnotationPresent(CompileReport.class), "SOURCE at runtime");
        require(!WorkOrderPolicy.class.isAnnotationPresent(ClassAudit.class), "CLASS at runtime");

        System.out.println("generated-source-seen=true");
        System.out.println("generated-entries=" + String.join("|", entries));
        System.out.println("runtime-roles=ADMIN|DISPATCHER");
        System.out.println("runtime-source=false runtime-class=false");
        System.out.println("inherited-role-count=2");
        System.out.println("LAB PASS");
    }

    private static void require(boolean condition, String message) {
        if (!condition) {
            throw new AssertionError(message);
        }
    }
}
