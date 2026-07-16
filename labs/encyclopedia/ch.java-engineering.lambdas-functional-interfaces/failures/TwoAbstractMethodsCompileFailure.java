public final class TwoAbstractMethodsCompileFailure {
    private TwoAbstractMethodsCompileFailure() {
    }

    interface BrokenRule {
        boolean accepts(int priority);

        String describe();
    }

    public static void main(String[] args) {
        BrokenRule rule = priority -> priority >= 3;
        System.out.println(rule.accepts(4));
    }
}
