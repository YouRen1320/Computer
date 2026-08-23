public final class MutableMoneyFailure {
    private static final class Money {
        public long cents;

        Money(long cents) {
            this.cents = cents;
        }

        Money plus(Money other) {
            cents += other.cents;
            return this;
        }
    }

    private MutableMoneyFailure() {
    }

    public static void main(String[] args) {
        Money base = new Money(5_000);
        Money result = base.plus(new Money(750));
        if (base.cents != 5_000) {
            System.err.println("IMMUTABILITY_BROKEN expectedOriginal=5000 actualOriginal=" + base.cents + " result=" + result.cents);
            System.exit(1);
        }
    }
}
