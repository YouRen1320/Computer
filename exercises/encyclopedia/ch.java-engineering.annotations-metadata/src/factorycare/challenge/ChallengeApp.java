package factorycare.challenge;

import java.lang.reflect.Method;

public final class ChallengeApp {
    @RequiresRole("ADMIN")
    @RequiresRole(value = "DISPATCHER", scope = Scope.REGION)
    static class BasePolicy {
        @RequiresRole("TECHNICIAN")
        void assign() {
        }
    }

    static final class ChildPolicy extends BasePolicy {
    }

    private ChallengeApp() {
    }

    public static void main(String[] args) throws Exception {
        RequiresRole[] direct = BasePolicy.class.getAnnotationsByType(RequiresRole.class);
        RequiresRole[] inherited = ChildPolicy.class.getAnnotationsByType(RequiresRole.class);
        Method assign = BasePolicy.class.getDeclaredMethod("assign");
        RequiresRole[] method = assign.getAnnotationsByType(RequiresRole.class);

        require(direct.length == 2, "direct repeatable roles");
        require(inherited.length == 2, "class inheritance");
        require(method.length == 1, "method target and runtime retention");
        require(direct[0].scope() == Scope.TENANT, "default scope");
        require(direct[1].scope() == Scope.REGION, "explicit scope");

        System.out.println("COMPLETED CHALLENGE PASS roles=2 inherited=2 method=1 default=TENANT");
    }

    private static void require(boolean condition, String message) {
        if (!condition) {
            throw new AssertionError("METADATA_CONTRACT " + message);
        }
    }
}
