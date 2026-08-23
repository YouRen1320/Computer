import java.math.BigDecimal;

public final class DoubleMoneyFailure {
    private DoubleMoneyFailure() {
    }

    public static void main(String[] args) {
        String actual = new BigDecimal(0.1d).toPlainString();
        if (!"0.1".equals(actual)) {
            System.err.println("DOUBLE_MONEY_ERROR expected=0.1 actual=" + actual);
            System.exit(4);
        }
        throw new AssertionError("fixture did not expose binary floating point");
    }
}
