import java.math.BigDecimal;

public final class PrecisionLossFailure {
    private PrecisionLossFailure() {
    }

    public static void main(String[] args) {
        BigDecimal fromToken = new BigDecimal("0.1");
        BigDecimal throughDouble = new BigDecimal(0.1);
        if (!fromToken.equals(throughDouble)) {
            throw new IllegalStateException("DOUBLE_PRECISION_LOSS actual="
                    + throughDouble.toPlainString());
        }
    }
}
