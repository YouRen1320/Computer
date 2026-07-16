package factorycare.failure;

import factorycare.metadata.CompileReport;
import factorycare.metadata.RequiresRole;

@CompileReport("invalid-role")
@RequiresRole("admin-user")
public final class InvalidRole {
}
