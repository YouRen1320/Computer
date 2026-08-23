import java.lang.reflect.Method;

final class SolutionHidden {
    private String secret() {
        return "secret";
    }
}

public final class PrivateAccessFailure {
    public static void main(String[] args) throws Exception {
        Method method = SolutionHidden.class.getDeclaredMethod("secret");
        try {
            method.invoke(new SolutionHidden());
        } catch (IllegalAccessException expected) {
            System.err.println("PRIVATE_ACCESS_DENIED canAccess=false exception=IllegalAccessException");
            System.exit(5);
        }
        throw new AssertionError("fixture did not fail");
    }
}
