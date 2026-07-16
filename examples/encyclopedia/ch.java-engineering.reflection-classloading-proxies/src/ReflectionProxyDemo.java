import java.lang.annotation.ElementType;
import java.lang.annotation.Retention;
import java.lang.annotation.RetentionPolicy;
import java.lang.annotation.Target;
import java.lang.reflect.InvocationHandler;
import java.lang.reflect.InvocationTargetException;
import java.lang.reflect.Method;
import java.lang.reflect.Proxy;
import java.util.ArrayList;
import java.util.List;

public final class ReflectionProxyDemo {
    private ReflectionProxyDemo() {
    }

    @Retention(RetentionPolicy.RUNTIME)
    @Target(ElementType.METHOD)
    @interface RequiresRole {
        String value();
    }

    interface DeviceAction {
        @RequiresRole("MAINTAINER")
        String inspect(String deviceId);

        String ping();

        String fail();
    }

    static final class DeviceActionImpl implements DeviceAction {
        private int calls;

        @Override
        public String inspect(String deviceId) {
            calls++;
            return "device=" + deviceId;
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

    static <T> T secureProxy(Class<T> contract, T target, String role, List<String> events) {
        if (!contract.isInterface()) {
            throw new IllegalArgumentException("contract must be an interface");
        }
        if (!contract.isInstance(target)) {
            throw new IllegalArgumentException("target must implement contract");
        }
        InvocationHandler handler = (proxy, method, args) -> {
            if (method.getDeclaringClass() == Object.class) {
                return handleObjectMethod(proxy, method, args, contract);
            }
            RequiresRole required = method.getAnnotation(RequiresRole.class);
            if (required != null && !required.value().equals(role)) {
                throw new SecurityException("required role=" + required.value());
            }
            events.add("before:" + method.getName());
            try {
                Object value = method.invoke(target, args);
                events.add("after:" + method.getName());
                return value;
            } catch (InvocationTargetException wrapper) {
                Throwable cause = wrapper.getCause();
                events.add("failure:" + method.getName() + ":" + cause.getClass().getSimpleName());
                throw cause;
            }
        };
        Object proxy = Proxy.newProxyInstance(contract.getClassLoader(), new Class<?>[] {contract}, handler);
        return contract.cast(proxy);
    }

    private static Object handleObjectMethod(Object proxy, Method method, Object[] args, Class<?> contract) {
        return switch (method.getName()) {
            case "toString" -> "Proxy[" + contract.getSimpleName() + "]";
            case "hashCode" -> System.identityHashCode(proxy);
            case "equals" -> proxy == args[0];
            default -> throw new AssertionError("unexpected Object method " + method.getName());
        };
    }

    public static void main(String[] args) throws Exception {
        int assertions = 0;
        DeviceActionImpl target = new DeviceActionImpl();
        Class<?> implementationType = target.getClass();
        Method inspect = DeviceAction.class.getMethod("inspect", String.class);
        RequiresRole annotation = inspect.getAnnotation(RequiresRole.class);
        assertions = check(implementationType == DeviceActionImpl.class, "class literal", assertions);
        assertions = check("DeviceActionImpl".equals(implementationType.getSimpleName()), "simple name", assertions);
        assertions = check(DeviceAction.class.isInterface(), "interface shape", assertions);
        assertions = check(DeviceAction.class.isAssignableFrom(DeviceActionImpl.class), "assignable direction", assertions);
        assertions = check(!DeviceActionImpl.class.isAssignableFrom(DeviceAction.class), "reverse direction", assertions);
        assertions = check(annotation != null && "MAINTAINER".equals(annotation.value()), "runtime annotation", assertions);
        assertions = check(java.lang.reflect.Modifier.isPublic(inspect.getModifiers()), "public interface method", assertions);

        List<String> events = new ArrayList<>();
        DeviceAction proxy = secureProxy(DeviceAction.class, target, "MAINTAINER", events);
        String result = proxy.inspect("A-17");
        assertions = check(proxy instanceof DeviceAction, "proxy implements interface", assertions);
        assertions = check(!(proxy instanceof DeviceActionImpl), "proxy is not target class", assertions);
        assertions = check("device=A-17".equals(result), "business result preserved", assertions);
        assertions = check(target.calls == 1, "single delegate call", assertions);
        assertions = check(events.equals(List.of("before:inspect", "after:inspect")), "event order", assertions);
        assertions = check("Proxy[DeviceAction]".equals(proxy.toString()), "safe proxy description", assertions);
        assertions = check(proxy.equals(proxy), "identity equals", assertions);
        assertions = check(!proxy.equals(target), "proxy not equal target", assertions);
        assertions = check(proxy.hashCode() == proxy.hashCode(), "stable identity hash", assertions);

        List<String> deniedEvents = new ArrayList<>();
        DeviceAction denied = secureProxy(DeviceAction.class, new DeviceActionImpl(), "VIEWER", deniedEvents);
        SecurityException deniedFailure = null;
        try {
            denied.inspect("A-17");
        } catch (SecurityException expected) {
            deniedFailure = expected;
        }
        assertions = check(deniedFailure != null && deniedFailure.getMessage().contains("MAINTAINER"),
                "role denied", assertions);
        assertions = check(deniedEvents.isEmpty(), "denied call not delegated", assertions);

        IllegalStateException targetFailure = null;
        try {
            proxy.fail();
        } catch (IllegalStateException expected) {
            targetFailure = expected;
        }
        assertions = check(targetFailure != null, "target failure type", assertions);
        assertions = check(targetFailure != null && "device offline".equals(targetFailure.getMessage()),
                "target failure message", assertions);
        assertions = check(events.contains("failure:fail:IllegalStateException")
                && !events.contains("after:fail"), "failure event", assertions);

        Thread thread = Thread.currentThread();
        ClassLoader original = thread.getContextClassLoader();
        ClassLoader rejecting = new ClassLoader(original) {
            @Override
            protected Class<?> loadClass(String name, boolean resolve) throws ClassNotFoundException {
                if (name.equals(DeviceAction.class.getName())) {
                    throw new ClassNotFoundException("blocked by fixture");
                }
                return super.loadClass(name, resolve);
            }
        };
        ClassNotFoundException loaderFailure = null;
        try {
            thread.setContextClassLoader(rejecting);
            Class.forName(DeviceAction.class.getName(), false, thread.getContextClassLoader());
        } catch (ClassNotFoundException expected) {
            loaderFailure = expected;
        } finally {
            thread.setContextClassLoader(original);
        }
        assertions = check(loaderFailure != null, "wrong context loader fails", assertions);
        assertions = check(thread.getContextClassLoader() == original, "context loader restored", assertions);
        assertions = check(proxy.getClass().getClassLoader() == DeviceAction.class.getClassLoader(),
                "proxy loader follows contract", assertions);

        System.out.println("class.interface=true");
        System.out.println("class.assignable=true");
        System.out.println("annotation.role=" + annotation.value());
        System.out.println("proxy.result=" + result);
        System.out.println("proxy.events=" + String.join(",", events));
        System.out.println("proxy.targetClass=false");
        System.out.println("proxy.denied=true");
        System.out.println("proxy.cause=" + targetFailure.getClass().getSimpleName());
        System.out.println("loader.rejected=true");
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
