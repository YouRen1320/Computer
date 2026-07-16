import java.util.function.Predicate;

public final class MethodReferenceMismatchCompileFailure {
    private MethodReferenceMismatchCompileFailure() {
    }

    static boolean atLeast(int priority, int threshold) {
        return priority >= threshold;
    }

    public static void main(String[] args) {
        Predicate<Integer> rule = MethodReferenceMismatchCompileFailure::atLeast;
        System.out.println(rule.test(4));
    }
}
