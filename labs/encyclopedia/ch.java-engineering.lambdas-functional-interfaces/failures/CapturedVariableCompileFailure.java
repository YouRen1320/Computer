import java.util.function.IntPredicate;

public final class CapturedVariableCompileFailure {
    private CapturedVariableCompileFailure() {
    }

    public static void main(String[] args) {
        int threshold = 3;
        IntPredicate urgent = priority -> priority >= threshold;
        threshold++;
        System.out.println(urgent.test(4));
    }
}
