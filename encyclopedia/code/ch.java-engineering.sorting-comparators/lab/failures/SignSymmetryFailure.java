import java.util.Comparator;

public final class SignSymmetryFailure {
    private SignSymmetryFailure() {
    }

    public static void main(String[] args) {
        Comparator<String> broken = (left, right) -> left.equals(right) ? 0 : 1;
        int ab = Integer.signum(broken.compare("A", "B"));
        int ba = Integer.signum(broken.compare("B", "A"));
        if (ab == ba) {
            throw new IllegalStateException("SIGN_SYMMETRY");
        }
    }
}
