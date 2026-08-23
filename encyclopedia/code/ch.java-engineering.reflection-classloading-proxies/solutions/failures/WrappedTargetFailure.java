import java.lang.reflect.InvocationTargetException;
import java.lang.reflect.Proxy;
import java.lang.reflect.UndeclaredThrowableException;

public final class WrappedTargetFailure {
    interface Task {
        void run();
    }

    public static void main(String[] args) {
        Task target = () -> { throw new IllegalStateException("offline"); };
        Task proxy = (Task) Proxy.newProxyInstance(Task.class.getClassLoader(), new Class<?>[] {Task.class},
                (ignored, method, values) -> method.invoke(target, values));
        try {
            proxy.run();
        } catch (UndeclaredThrowableException actual) {
            if (actual.getCause() instanceof InvocationTargetException) {
                System.err.println("WRAPPED_TARGET expected=IllegalStateException actual=InvocationTargetException");
                System.exit(7);
            }
        }
        throw new AssertionError("fixture did not fail");
    }
}
