public final class MoneyChallenge {
    private MoneyChallenge() {
    }

    private static final class Money {
        public long cents;
        public String currency;

        Money(long cents, String currency) {
            this.cents = cents;
            this.currency = currency;
        }

        Money plus(Money other) {
            cents += other.cents;
            return this;
        }
    }

    public static void main(String[] args) {
        Money base = new Money(5_000, "CNY");
        Money fee = new Money(750, "CNY");
        Money total = base.plus(fee);
        int assertions = 0;
        assertions = check(total.cents == 5_750, "result", assertions);
        if (base.cents != 5_000) {
            System.err.println("STARTER_MUTATION expectedOriginal=5000 actualOriginal=" + base.cents);
            System.exit(1);
        }

        assertions = check(base.cents == 5_000, "base unchanged", assertions);
        assertions = check(fee.cents == 750, "fee unchanged", assertions);
        assertions = check(total != base, "new identity", assertions);
        assertions = check("CNY".equals(total.currency), "currency", assertions);
        assertions = check(total.cents > base.cents, "sum larger", assertions);
        assertions = check(base.cents >= 0, "base valid", assertions);
        assertions = check(fee.cents >= 0, "fee valid", assertions);
        assertions = check(total.cents >= 0, "total valid", assertions);
        assertions = check(base != fee, "inputs distinct", assertions);
        System.out.println("exercise.assertions=" + assertions + " passed");
    }

    private static int check(boolean condition, String message, int assertions) {
        if (!condition) {
            throw new AssertionError(message);
        }
        return assertions + 1;
    }
}
