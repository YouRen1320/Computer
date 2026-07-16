import java.lang.reflect.Method;

final class LabHiddenTarget {
    private void hidden() {
    }
}

public final class PrivateAccessFailure {
    public static void main(String[] args) throws Exception {
        Method method = LabHiddenTarget.class.getDeclaredMethod("hidden");
        try {
            method.invoke(new LabHiddenTarget());
        } catch (IllegalAccessException expected) {
            System.err.println("PRIVATE_ACCESS_DENIED canAccess=false exception=IllegalAccessException");
            System.exit(5);
        }
        throw new AssertionError("fixture did not fail");
    }
}
