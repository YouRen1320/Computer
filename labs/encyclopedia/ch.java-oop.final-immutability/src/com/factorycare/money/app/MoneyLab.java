package com.factorycare.money.app;

import com.factorycare.money.domain.MaintenanceWindow;
import com.factorycare.money.domain.Money;

public final class MoneyLab {
    private MoneyLab() {
    }

    public static void main(String[] args) {
        int assertions = 0;
        Money base = new Money(5_000, "CNY");
        Money fee = new Money(750, "CNY");
        Money total = base.plus(fee);
        assertions = check(base.cents() == 5_000, "base value", assertions);
        assertions = check("CNY".equals(base.currency()), "currency", assertions);
        assertions = check(total.cents() == 5_750, "sum", assertions);
        assertions = check(total != base, "new identity", assertions);
        assertions = check(base.cents() == 5_000, "base unchanged", assertions);
        assertions = check(fee.cents() == 750, "fee unchanged", assertions);
        assertions = expectIllegal(() -> new Money(-1, "CNY"), "negative", assertions);
        assertions = expectIllegal(() -> new Money(1, null), "null currency", assertions);
        assertions = expectIllegal(() -> new Money(1, " "), "blank currency", assertions);
        assertions = expectIllegal(() -> base.plus(new Money(1, "USD")), "currency mismatch", assertions);
        assertions = expectArithmetic(() -> new Money(Long.MAX_VALUE, "CNY").plus(new Money(1, "CNY")), "overflow", assertions);

        int[] source = {8, 10};
        MaintenanceWindow window = new MaintenanceWindow(source);
        source[0] = 23;
        assertions = check(window.hours()[0] == 8, "input isolated", assertions);
        int[] firstRead = window.hours();
        firstRead[1] = 0;
        assertions = check(window.hours()[1] == 10, "output isolated", assertions);
        assertions = check(firstRead != window.hours(), "query copies", assertions);
        assertions = check(window.hours().length == 2, "length", assertions);
        assertions = check(window.hours()[0] == 8 && window.hours()[1] == 10, "content", assertions);

        System.out.println("base=" + base.cents() + "|" + base.currency());
        System.out.println("total=" + total.cents() + "|" + total.currency());
        System.out.println("hours=" + window.hours()[0] + "," + window.hours()[1]);
        System.out.println("lab.assertions=" + assertions + " passed");
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
