public final class WrongContextLoaderFailure {
    private WrongContextLoaderFailure() {
    }

    interface Contract {
    }

    public static void main(String[] args) throws Exception {
        Thread thread = Thread.currentThread();
        ClassLoader original = thread.getContextClassLoader();
        ClassLoader rejecting = new ClassLoader(original) {
            @Override
            protected Class<?> loadClass(String name, boolean resolve) throws ClassNotFoundException {
                if (name.equals(Contract.class.getName())) {
                    throw new ClassNotFoundException("fixture rejected contract");
                }
                return super.loadClass(name, resolve);
            }
        };
        boolean failed = false;
        try {
            thread.setContextClassLoader(rejecting);
            Class.forName(Contract.class.getName(), false, thread.getContextClassLoader());
        } catch (ClassNotFoundException expected) {
            failed = true;
        } finally {
            thread.setContextClassLoader(original);
        }
        if (failed && thread.getContextClassLoader() == original) {
            System.err.println("WRONG_CONTEXT_LOADER classFound=false restored=true");
            System.exit(6);
        }
        throw new AssertionError("context loader fixture failed");
    }
}
