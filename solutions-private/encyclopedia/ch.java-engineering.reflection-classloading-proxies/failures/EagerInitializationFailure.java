public final class EagerInitializationFailure {
    private static int events;

    static final class SideEffect {
        static {
            events++;
        }
    }

    public static void main(String[] args) throws Exception {
        String name = SideEffect.class.getName();
        boolean before = events == 0;
        Class.forName(name);
        if (before && events == 1) {
            System.err.println("EAGER_INITIALIZATION before=0 after=1");
            System.exit(8);
        }
        throw new AssertionError("fixture did not fail");
    }
}
