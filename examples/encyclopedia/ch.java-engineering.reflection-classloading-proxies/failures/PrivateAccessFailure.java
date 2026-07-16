import java.lang.reflect.Method;

final class HiddenAccessTarget {
    private String secret() {
        return "secret";
    }
}

public final class PrivateAccessFailure {
    private PrivateAccessFailure() {
    }

    public static void main(String[] args) throws Exception {
        Method method = HiddenAccessTarget.class.getDeclaredMethod("secret");
        try {
            method.invoke(new HiddenAccessTarget());
            throw new AssertionError("private method unexpectedly accessible");
        } catch (IllegalAccessException expected) {
            System.err.println("PRIVATE_ACCESS_DENIED canAccess=false exception=IllegalAccessException");
            System.exit(5);
        }
    }
}
