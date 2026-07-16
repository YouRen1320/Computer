import java.math.BigDecimal;

public final class ScaleEqualityFailure {
    private ScaleEqualityFailure() {
    }

    public static void main(String[] args) {
        BigDecimal left = new BigDecimal("10.0");
        BigDecimal right = new BigDecimal("10.00");
        if (!left.equals(right) && left.compareTo(right) == 0) {
            System.err.println("SCALE_EQUALITY_FAILURE leftScale=1 rightScale=2 equals=false compareTo=0");
            System.exit(5);
        }
        throw new AssertionError("fixture did not expose scale-sensitive equality");
    }
}
