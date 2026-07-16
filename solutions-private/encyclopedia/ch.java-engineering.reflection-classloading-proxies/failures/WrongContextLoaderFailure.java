public final class WrongContextLoaderFailure {
    interface Contract {
    }

    public static void main(String[] args) throws Exception {
        ClassLoader rejecting = new ClassLoader(Contract.class.getClassLoader()) {
            @Override
            protected Class<?> loadClass(String name, boolean resolve) throws ClassNotFoundException {
                if (name.equals(Contract.class.getName())) {
                    throw new ClassNotFoundException(name);
                }
                return super.loadClass(name, resolve);
            }
        };
        try {
            Class.forName(Contract.class.getName(), false, rejecting);
        } catch (ClassNotFoundException expected) {
            System.err.println("WRONG_CONTEXT_LOADER classFound=false explicitContractLoader=true");
            System.exit(6);
        }
        throw new AssertionError("fixture did not fail");
    }
}
