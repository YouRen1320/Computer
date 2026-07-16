import java.lang.reflect.Proxy;

public final class NoInterfaceProxyFailure {
    private NoInterfaceProxyFailure() {
    }

    static final class ConcreteOnly {
    }

    public static void main(String[] args) {
        try {
            Proxy.newProxyInstance(ConcreteOnly.class.getClassLoader(),
                    new Class<?>[] {ConcreteOnly.class},
                    (proxy, method, arguments) -> null);
            throw new AssertionError("concrete class unexpectedly accepted");
        } catch (IllegalArgumentException expected) {
            System.err.println("NO_INTERFACE_PROXY contractInterface=false exception=IllegalArgumentException");
            System.exit(4);
        }
    }
}
