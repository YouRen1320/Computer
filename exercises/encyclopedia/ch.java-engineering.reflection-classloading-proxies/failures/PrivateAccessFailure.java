import java.lang.reflect.Method;

final class ExerciseHidden {
    private void secret() {
    }
}

public final class PrivateAccessFailure {
    public static void main(String[] args) throws Exception {
        Method method = ExerciseHidden.class.getDeclaredMethod("secret");
        try {
            method.invoke(new ExerciseHidden());
        } catch (IllegalAccessException expected) {
            System.err.println("PRIVATE_ACCESS_DENIED canAccess=false exception=IllegalAccessException");
            System.exit(5);
        }
        throw new AssertionError("fixture did not fail");
    }
}
