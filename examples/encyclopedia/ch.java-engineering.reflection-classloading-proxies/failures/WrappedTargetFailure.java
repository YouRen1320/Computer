import java.lang.reflect.InvocationTargetException;
import java.lang.reflect.Proxy;
import java.lang.reflect.UndeclaredThrowableException;

public final class WrappedTargetFailure {
    private WrappedTargetFailure() {
    }

    interface Task {
        void run();
    }

    static final class FailingTask implements Task {
        @Override
        public void run() {
            throw new IllegalStateException("device offline");
        }
    }

    public static void main(String[] args) {
        Task target = new FailingTask();
        Task proxy = (Task) Proxy.newProxyInstance(Task.class.getClassLoader(), new Class<?>[] {Task.class},
                (ignored, method, arguments) -> method.invoke(target, arguments));
        try {
            proxy.run();
            throw new AssertionError("target failure unexpectedly hidden");
        } catch (UndeclaredThrowableException actual) {
            if (actual.getCause() instanceof InvocationTargetException) {
                System.err.println("WRAPPED_TARGET expected=IllegalStateException actual=InvocationTargetException");
                System.exit(7);
            }
            throw actual;
        }
    }
}
