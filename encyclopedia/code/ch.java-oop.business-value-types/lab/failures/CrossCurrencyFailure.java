import java.math.BigDecimal;

public final class CrossCurrencyFailure {
    private CrossCurrencyFailure() {
    }

    record BrokenMoney(BigDecimal amount, String currency) {
        BrokenMoney add(BrokenMoney other) {
            return new BrokenMoney(amount.add(other.amount), currency);
        }
    }

    public static void main(String[] args) {
        BrokenMoney result = new BrokenMoney(new BigDecimal("10.00"), "CNY")
                .add(new BrokenMoney(new BigDecimal("2.00"), "USD"));
        if ("CNY".equals(result.currency()) && result.amount().compareTo(new BigDecimal("12.00")) == 0) {
            System.err.println("CROSS_CURRENCY_ACCEPTED left=CNY right=USD result=CNY-12.00");
            System.exit(8);
        }
        throw new AssertionError("fixture did not combine currencies incorrectly");
    }
}
