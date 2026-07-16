public final class MoneySolution {
    private MoneySolution() {
    }

    private static final class Money {
        private final long cents;
        private final String currency;

        Money(long cents, String currency) {
            if (cents < 0) {
                throw new IllegalArgumentException("cents must not be negative");
            }
            if (currency == null || currency.isBlank()) {
                throw new IllegalArgumentException("currency must have text");
            }
            this.cents = cents;
            this.currency = currency;
        }

        Money plus(Money other) {
            if (other == null) {
                throw new IllegalArgumentException("other must not be null");
            }
            if (!currency.equals(other.currency)) {
                throw new IllegalArgumentException("currency mismatch");
            }
            return new Money(Math.addExact(cents, other.cents), currency);
        }
    }

    public static void main(String[] args) {
        Money base = new Money(5_000, "CNY");
        Money fee = new Money(750, "CNY");
        Money total = base.plus(fee);
        int assertions = 0;
        assertions = check(total.cents == 5_750, "result", assertions);
        assertions = check(base.cents == 5_000, "base unchanged", assertions);
        assertions = check(fee.cents == 750, "fee unchanged", assertions);
        assertions = check(total != base, "new identity", assertions);
        assertions = check("CNY".equals(total.currency), "currency", assertions);
        assertions = expectIllegal(() -> new Money(-1, "CNY"), "negative", assertions);
        assertions = expectIllegal(() -> new Money(1, null), "null currency", assertions);
        assertions = expectIllegal(() -> new Money(1, " "), "blank currency", assertions);
        assertions = expectIllegal(() -> base.plus(new Money(1, "USD")), "mismatch", assertions);
        assertions = expectArithmetic(() -> new Money(Long.MAX_VALUE, "CNY").plus(new Money(1, "CNY")), "overflow", assertions);
        System.out.println("solution.assertions=" + assertions + " passed");
    }

    private static int check(boolean condition, String message, int assertions) {
        if (!condition) {
            throw new AssertionError(message);
        }
        return assertions + 1;
    }

    private static int expectIllegal(Action action, String message, int assertions) {
        try {
            action.run();
            throw new AssertionError("expected IllegalArgumentException: " + message);
        } catch (IllegalArgumentException expected) {
            return assertions + 1;
        }
    }

    private static int expectArithmetic(Action action, String message, int assertions) {
        try {
            action.run();
            throw new AssertionError("expected ArithmeticException: " + message);
        } catch (ArithmeticException expected) {
            return assertions + 1;
        }
    }

    @FunctionalInterface
    private interface Action {
        void run();
    }
}
