import java.lang.annotation.ElementType;
import java.lang.annotation.Retention;
import java.lang.annotation.RetentionPolicy;
import java.lang.annotation.Target;
import java.lang.reflect.Proxy;

public final class ReflectionProxyChallenge {
    private ReflectionProxyChallenge() {
    }

    @Retention(RetentionPolicy.RUNTIME)
    @Target(ElementType.METHOD)
    @interface RequiresRole {
        String value();
    }

    interface DeviceAction {
        @RequiresRole("MAINTAINER")
        String inspect(String id);

        String fail();
    }

    static final class DeviceActionImpl implements DeviceAction {
        private int calls;

        @Override
        public String inspect(String id) {
            calls++;
            return "device=" + id;
        }

        @Override
        public String fail() {
            calls++;
            throw new IllegalStateException("device offline");
        }
    }

    static <T> T brokenProxy(Class<T> contract, T target, String role) {
        // TODO：验证接口/目标，读取 RequiresRole，使用 contract loader，并解包目标 cause。
        Object proxy = Proxy.newProxyInstance(Thread.currentThread().getContextClassLoader(),
                new Class<?>[] {contract},
                (ignored, method, arguments) -> method.invoke(target, arguments));
        return contract.cast(proxy);
    }

    public static void main(String[] args) throws Exception {
        DeviceActionImpl deniedTarget = new DeviceActionImpl();
        DeviceAction denied = brokenProxy(DeviceAction.class, deniedTarget, "VIEWER");
        SecurityException deniedFailure = null;
        String bypassed = null;
        try {
            bypassed = denied.inspect("A-17");
        } catch (SecurityException expected) {
            deniedFailure = expected;
        }
        if (deniedFailure == null) {
            System.err.println("STARTER_AUTH_BYPASS expected=SecurityException actual=" + bypassed);
            System.exit(8);
        }

        DeviceActionImpl target = new DeviceActionImpl();
        DeviceAction authorized = brokenProxy(DeviceAction.class, target, "MAINTAINER");
        String result = authorized.inspect("A-17");
        IllegalStateException targetFailure = null;
        try {
            authorized.fail();
        } catch (IllegalStateException expected) {
            targetFailure = expected;
        } catch (RuntimeException wrapper) {
            System.err.println("PARTIAL_TARGET_WRAPPED expected=IllegalStateException actual="
                    + wrapper.getClass().getSimpleName());
            System.exit(9);
        }

        Thread thread = Thread.currentThread();
        ClassLoader original = thread.getContextClassLoader();
        ClassLoader rejecting = new ClassLoader(original) {
            @Override
            protected Class<?> loadClass(String name, boolean resolve) throws ClassNotFoundException {
                if (name.equals(DeviceAction.class.getName())) {
                    throw new ClassNotFoundException(name);
                }
                return super.loadClass(name, resolve);
            }
        };
        boolean explicitLoaderWorked = false;
        boolean wrongLoaderObserved = false;
        try {
            thread.setContextClassLoader(rejecting);
            DeviceAction independent = brokenProxy(DeviceAction.class, new DeviceActionImpl(), "MAINTAINER");
            explicitLoaderWorked = "device=B-02".equals(independent.inspect("B-02"));
        } catch (IllegalArgumentException wrongLoader) {
            wrongLoaderObserved = true;
        } finally {
            thread.setContextClassLoader(original);
        }
        if (wrongLoaderObserved) {
            System.err.println("PARTIAL_WRONG_LOADER expected=contract-loader actual=context-loader");
            System.exit(10);
        }

        int assertions = 0;
        RequiresRole annotation = DeviceAction.class.getMethod("inspect", String.class)
                .getAnnotation(RequiresRole.class);
        assertions = check(DeviceAction.class.isInterface(), "interface", assertions);
        assertions = check(annotation != null && "MAINTAINER".equals(annotation.value()), "annotation", assertions);
        assertions = check(deniedFailure != null, "denied", assertions);
        assertions = check(deniedTarget.calls == 0, "denied not delegated", assertions);
        assertions = check("device=A-17".equals(result), "result", assertions);
        assertions = check(target.calls == 2, "two target calls", assertions);
        assertions = check(targetFailure != null && "device offline".equals(targetFailure.getMessage()),
                "cause", assertions);
        assertions = check(explicitLoaderWorked, "explicit loader", assertions);
        assertions = check(thread.getContextClassLoader() == original, "loader restored", assertions);
        assertions = check(Proxy.isProxyClass(authorized.getClass()), "proxy class", assertions);
        System.out.println("challenge.assertions=" + assertions + " passed");
    }

    private static int check(boolean condition, String message, int assertions) {
        if (!condition) {
            throw new AssertionError(message);
        }
        return assertions + 1;
    }
}
