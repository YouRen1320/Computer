import java.lang.reflect.Proxy;

public final class NoInterfaceProxyFailure {
    static final class ConcreteOnly {
    }

    public static void main(String[] args) {
        try {
            Proxy.newProxyInstance(ConcreteOnly.class.getClassLoader(), new Class<?>[] {ConcreteOnly.class},
                    (proxy, method, values) -> null);
        } catch (IllegalArgumentException expected) {
            System.err.println("NO_INTERFACE_PROXY contractInterface=false exception=IllegalArgumentException");
            System.exit(4);
        }
        throw new AssertionError("fixture did not fail");
    }
}
