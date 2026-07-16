import java.lang.annotation.ElementType;
import java.lang.annotation.Retention;
import java.lang.annotation.RetentionPolicy;
import java.lang.annotation.Target;
import java.lang.reflect.InvocationTargetException;
import java.lang.reflect.Method;
import java.lang.reflect.Proxy;
import java.util.ArrayList;
import java.util.List;

public final class ReflectionProxySolution {
    private ReflectionProxySolution() {
    }

    @Retention(RetentionPolicy.RUNTIME)
    @Target(ElementType.METHOD)
    @interface RequiresRole {
        String value();
    }

    interface DeviceAction {
        @RequiresRole("MAINTAINER")
        String inspect(String id);

        String ping();

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
        public String ping() {
            calls++;
            return "pong";
        }

        @Override
        public String fail() {
            calls++;
            throw new IllegalStateException("device offline");
        }
    }

    static <T> T createProxy(Class<T> contract, T target, String role, List<String> events) {
        if (contract == null || target == null || role == null || events == null) {
            throw new IllegalArgumentException("proxy inputs required");
        }
        if (!contract.isInterface()) {
            throw new IllegalArgumentException("contract must be interface");
        }
        if (!contract.isInstance(target)) {
            throw new IllegalArgumentException("target does not implement contract");
        }
        Object proxy = Proxy.newProxyInstance(contract.getClassLoader(), new Class<?>[] {contract},
                (self, method, arguments) -> {
                    if (method.getDeclaringClass() == Object.class) {
                        return objectMethod(self, method, arguments, contract);
                    }
                    RequiresRole required = method.getAnnotation(RequiresRole.class);
                    if (required != null && !required.value().equals(role)) {
                        throw new SecurityException("required=" + required.value());
                    }
                    events.add("before:" + method.getName());
                    try {
                        Object result = method.invoke(target, arguments);
                        events.add("after:" + method.getName());
                        return result;
                    } catch (InvocationTargetException wrapper) {
                        Throwable cause = wrapper.getCause();
                        events.add("failure:" + method.getName() + ":" + cause.getClass().getSimpleName());
                        throw cause;
                    }
                });
        return contract.cast(proxy);
    }

    private static Object objectMethod(Object proxy, Method method, Object[] arguments, Class<?> contract) {
        return switch (method.getName()) {
            case "toString" -> "SecureProxy[" + contract.getSimpleName() + "]";
            case "hashCode" -> System.identityHashCode(proxy);
            case "equals" -> proxy == arguments[0];
            default -> throw new AssertionError(method.getName());
        };
    }

    public static void main(String[] args) throws Exception {
        int assertions = 0;
        DeviceActionImpl target = new DeviceActionImpl();
        List<String> events = new ArrayList<>();
        DeviceAction proxy = createProxy(DeviceAction.class, target, "MAINTAINER", events);
        Method inspect = DeviceAction.class.getMethod("inspect", String.class);
        RequiresRole required = inspect.getAnnotation(RequiresRole.class);
        assertions = check(DeviceAction.class.isInterface(), "interface", assertions);
        assertions = check(DeviceAction.class.isInstance(target), "target type", assertions);
        assertions = check(required != null && "MAINTAINER".equals(required.value()), "annotation", assertions);
        assertions = check("device=A-17".equals(proxy.inspect("A-17")), "result", assertions);
        assertions = check(target.calls == 1, "one call", assertions);
        assertions = check(events.equals(List.of("before:inspect", "after:inspect")), "events", assertions);
        assertions = check("SecureProxy[DeviceAction]".equals(proxy.toString()), "description", assertions);
        assertions = check(proxy.equals(proxy) && !proxy.equals(target), "equals policy", assertions);
        assertions = check(proxy.hashCode() == proxy.hashCode(), "hash policy", assertions);
        assertions = check(Proxy.isProxyClass(proxy.getClass()), "proxy class", assertions);
        assertions = check(proxy.getClass().getClassLoader() == DeviceAction.class.getClassLoader(), "loader", assertions);

        DeviceActionImpl deniedTarget = new DeviceActionImpl();
        DeviceAction denied = createProxy(DeviceAction.class, deniedTarget, "VIEWER", new ArrayList<>());
        SecurityException deniedFailure = null;
        try {
            denied.inspect("A-17");
        } catch (SecurityException expected) {
            deniedFailure = expected;
        }
        assertions = check(deniedFailure != null, "denied", assertions);
        assertions = check(deniedTarget.calls == 0, "not delegated", assertions);

        IllegalStateException targetFailure = null;
        try {
            proxy.fail();
        } catch (IllegalStateException expected) {
            targetFailure = expected;
        }
        assertions = check(targetFailure != null && "device offline".equals(targetFailure.getMessage()),
                "target cause", assertions);
        assertions = check(target.calls == 2, "failure delegated once", assertions);
        assertions = check(events.contains("failure:fail:IllegalStateException") && !events.contains("after:fail"),
                "failure event", assertions);

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
        boolean rejected = false;
        try {
            thread.setContextClassLoader(rejecting);
            Class.forName(DeviceAction.class.getName(), false, thread.getContextClassLoader());
        } catch (ClassNotFoundException expected) {
            rejected = true;
        } finally {
            thread.setContextClassLoader(original);
        }
        assertions = check(rejected, "wrong loader rejected", assertions);
        assertions = check(thread.getContextClassLoader() == original, "loader restored", assertions);
        assertions = check(Class.forName(DeviceAction.class.getName(), false, DeviceAction.class.getClassLoader())
                == DeviceAction.class, "explicit loader succeeds", assertions);

        System.out.println("solution.annotation=" + required.value());
        System.out.println("solution.result=device=A-17");
        System.out.println("solution.events=" + String.join(",", events));
        System.out.println("solution.denied=true");
        System.out.println("solution.cause=" + targetFailure.getClass().getSimpleName());
        System.out.println("solution.loaderRestored=true");
        System.out.println("solution.assertions=" + assertions + " passed");
    }

    private static int check(boolean condition, String message, int assertions) {
        if (!condition) {
            throw new AssertionError(message);
        }
        return assertions + 1;
    }
}
