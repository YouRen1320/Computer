package factorycare.app;

import factorycare.metadata.ClassAudit;
import factorycare.metadata.CompileReport;
import factorycare.metadata.RequiresRole;
import factorycare.metadata.Scope;

@CompileReport("factorycare-role-index")
@ClassAudit("class-file-evidence")
@RequiresRole("ADMIN")
@RequiresRole(value = "DISPATCHER", scope = Scope.REGION)
public class WorkOrderPolicy {
}
