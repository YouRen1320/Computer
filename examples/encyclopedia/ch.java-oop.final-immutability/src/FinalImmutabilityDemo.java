public final class FinalImmutabilityDemo {
    private static final String DEFAULT_CURRENCY = "CNY";

    private FinalImmutabilityDemo() {
    }

    private static final class MutableBox {
        private int value = 1;

        void increment() {
            value++;
        }
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
            if (!currency.equals(other.currency)) {
                throw new IllegalArgumentException("currency mismatch");
            }
            return new Money(Math.addExact(cents, other.cents), currency);
        }
    }

    private static final class MaintenanceWindow {
        private final int[] hours;

        MaintenanceWindow(int[] hours) {
            if (hours == null || hours.length == 0) {
                throw new IllegalArgumentException("hours must not be empty");
            }
            this.hours = hours.clone();
        }

        int[] hours() {
            return hours.clone();
        }
    }

    public static void main(String[] args) {
        int assertions = 0;
        final MutableBox box = new MutableBox();
        MutableBox alias = box;
        box.increment();
        assertions = check(box == alias, "final binding still points to same box", assertions);
        assertions = check(box.value == 2, "referenced object remains mutable", assertions);

        Money base = new Money(5_000, DEFAULT_CURRENCY);
        Money fee = new Money(750, DEFAULT_CURRENCY);
        Money total = base.plus(fee);
        assertions = check(total.cents == 5_750, "sum", assertions);
        assertions = check(base.cents == 5_000, "base unchanged", assertions);
        assertions = check(fee.cents == 750, "fee unchanged", assertions);
        assertions = check(total != base, "new object returned", assertions);
        assertions = expectIllegal(() -> new Money(-1, DEFAULT_CURRENCY), "negative", assertions);
        assertions = expectIllegal(() -> base.plus(new Money(1, "USD")), "currency mismatch", assertions);

        int[] source = {8, 10};
        MaintenanceWindow window = new MaintenanceWindow(source);
        source[0] = 23;
        assertions = check(window.hours()[0] == 8, "input copied", assertions);
        int[] observed = window.hours();
        observed[1] = 0;
        assertions = check(window.hours()[1] == 10, "output copied", assertions);
        assertions = check(observed != window.hours(), "each query returns a copy", assertions);
        assertions = check(window.hours().length == 2, "shape retained", assertions);

        System.out.println("constant=" + DEFAULT_CURRENCY);
        System.out.println("reference.same=" + (box == alias));
        System.out.println("reference.value=" + box.value);
        System.out.println("base=" + base.cents);
        System.out.println("result=" + total.cents);
        System.out.println("baseAfter=" + base.cents);
        System.out.println("inputIsolated=" + window.hours()[0]);
        System.out.println("outputIsolated=" + window.hours()[1]);
        System.out.println("assertions=" + assertions + " passed");
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

    @FunctionalInterface
    private interface Action {
        void run();
    }
}
