import java.lang.annotation.ElementType;
import java.lang.annotation.Retention;
import java.lang.annotation.RetentionPolicy;
import java.lang.annotation.Target;
import java.lang.reflect.InvocationTargetException;
import java.lang.reflect.Method;
import java.lang.reflect.Proxy;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;

public final class ReflectionClassloadingLab {
    private static int initializationEvents;

    private ReflectionClassloadingLab() {
    }

    static final class LazyType {
        static {
            initializationEvents++;
        }
    }

    @Retention(RetentionPolicy.RUNTIME)
    @Target(ElementType.METHOD)
    @interface RequiresRole {
        String value();
    }

    interface DeviceOps {
        String inspect(String id);

        @RequiresRole("MAINTAINER")
        String repair(String id);

        String fail();
    }

    static final class DeviceOpsImpl implements DeviceOps {
        private int calls;

        @Override
        public String inspect(String id) {
            calls++;
            return "inspect:" + id;
        }

        @Override
        public String repair(String id) {
            calls++;
            return "repair:" + id;
        }

        @Override
        public String fail() {
            calls++;
            throw new IllegalArgumentException("invalid device");
        }
    }

    static <T> T proxy(Class<T> contract, T target, String role, List<String> events) {
        if (!contract.isInterface() || !contract.isInstance(target)) {
            throw new IllegalArgumentException("explicit interface contract required");
        }
        Object value = Proxy.newProxyInstance(contract.getClassLoader(), new Class<?>[] {contract},
                (proxy, method, arguments) -> {
                    if (method.getDeclaringClass() == Object.class) {
                        return switch (method.getName()) {
                            case "toString" -> "RoleProxy[" + contract.getSimpleName() + "]";
                            case "hashCode" -> System.identityHashCode(proxy);
                            case "equals" -> proxy == arguments[0];
                            default -> throw new AssertionError(method.getName());
                        };
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
        return contract.cast(value);
    }

    public static void main(String[] args) throws Exception {
        int assertions = 0;
        String lazyName = LazyType.class.getName();
        assertions = check(initializationEvents == 0, "class literal does not initialize", assertions);
        Class<?> loaded = Class.forName(lazyName, false, LazyType.class.getClassLoader());
        assertions = check(loaded == LazyType.class, "same defining loader", assertions);
        assertions = check(initializationEvents == 0, "initialize false", assertions);
        Class.forName(lazyName, true, LazyType.class.getClassLoader());
        assertions = check(initializationEvents == 1, "initialize true", assertions);

        Method repair = DeviceOps.class.getMethod("repair", String.class);
        RequiresRole required = repair.getAnnotation(RequiresRole.class);
        String[] methodNames = Arrays.stream(DeviceOps.class.getDeclaredMethods())
                .map(Method::getName)
                .sorted()
                .toArray(String[]::new);
        assertions = check(Arrays.equals(methodNames, new String[] {"fail", "inspect", "repair"}),
                "stable method report", assertions);
        assertions = check(required != null && "MAINTAINER".equals(required.value()), "role metadata", assertions);
        assertions = check(repair.canAccess(new DeviceOpsImpl()), "public access", assertions);
        assertions = check(DeviceOps.class.isAssignableFrom(DeviceOpsImpl.class), "assignability", assertions);

        DeviceOpsImpl target = new DeviceOpsImpl();
        List<String> events = new ArrayList<>();
        DeviceOps secured = proxy(DeviceOps.class, target, "MAINTAINER", events);
        assertions = check("inspect:A-17".equals(secured.inspect("A-17")), "unannotated call", assertions);
        assertions = check("repair:A-17".equals(secured.repair("A-17")), "authorized call", assertions);
        assertions = check(target.calls == 2, "two delegate calls", assertions);
        assertions = check(events.equals(List.of("before:inspect", "after:inspect", "before:repair", "after:repair")),
                "event order", assertions);
        assertions = check("RoleProxy[DeviceOps]".equals(secured.toString()), "Object method policy", assertions);
        assertions = check(secured.equals(secured), "identity equals", assertions);
        assertions = check(secured.hashCode() == secured.hashCode(), "identity hash", assertions);

        DeviceOps denied = proxy(DeviceOps.class, new DeviceOpsImpl(), "VIEWER", new ArrayList<>());
        SecurityException deniedFailure = null;
        try {
            denied.repair("A-17");
        } catch (SecurityException expected) {
            deniedFailure = expected;
        }
        assertions = check(deniedFailure != null, "authorization failure", assertions);

        IllegalArgumentException targetFailure = null;
        try {
            secured.fail();
        } catch (IllegalArgumentException expected) {
            targetFailure = expected;
        }
        assertions = check(targetFailure != null && "invalid device".equals(targetFailure.getMessage()),
                "target cause unwrapped", assertions);
        assertions = check(target.calls == 3, "failing target called once", assertions);
        assertions = check(events.contains("failure:fail:IllegalArgumentException")
                && !events.contains("after:fail"), "failure events", assertions);

        Thread thread = Thread.currentThread();
        ClassLoader original = thread.getContextClassLoader();
        ClassLoader rejectContract = new ClassLoader(original) {
            @Override
            protected Class<?> loadClass(String name, boolean resolve) throws ClassNotFoundException {
                if (name.equals(DeviceOps.class.getName())) {
                    throw new ClassNotFoundException("contract blocked");
                }
                return super.loadClass(name, resolve);
            }
        };
        ClassNotFoundException wrongLoader = null;
        try {
            thread.setContextClassLoader(rejectContract);
            Class.forName(DeviceOps.class.getName(), false, thread.getContextClassLoader());
        } catch (ClassNotFoundException expected) {
            wrongLoader = expected;
        } finally {
            thread.setContextClassLoader(original);
        }
        assertions = check(wrongLoader != null, "wrong context loader", assertions);
        assertions = check(thread.getContextClassLoader() == original, "context restored", assertions);
        assertions = check(secured.getClass().getClassLoader() == DeviceOps.class.getClassLoader(),
                "proxy loader", assertions);
        assertions = check(Proxy.isProxyClass(secured.getClass()), "proxy class recognized", assertions);
        assertions = check(Proxy.getInvocationHandler(secured) != null, "handler available", assertions);
        assertions = check(!(secured instanceof DeviceOpsImpl), "not concrete subclass", assertions);
        assertions = check(DeviceOps.class.cast(secured) == secured, "typed cast", assertions);

        System.out.println("initialization.before=false");
        System.out.println("initialization.after=true");
        System.out.println("methods=" + String.join(",", methodNames));
        System.out.println("annotation.role=" + required.value());
        System.out.println("proxy.calls=" + target.calls);
        System.out.println("proxy.events=" + String.join(",", events));
        System.out.println("proxy.cause=" + targetFailure.getClass().getSimpleName());
        System.out.println("loader.restored=true");
        System.out.println("assertions=" + assertions + " passed");
    }

    private static int check(boolean condition, String message, int assertions) {
        if (!condition) {
            throw new AssertionError(message);
        }
        return assertions + 1;
    }
}
