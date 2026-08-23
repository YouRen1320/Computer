import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.Instant;
import java.time.ZoneId;
import java.time.ZonedDateTime;
import java.util.UUID;
import java.util.regex.Pattern;

public final class BusinessValueTypesDemo {
    private BusinessValueTypesDemo() {
    }

    static final class Money {
        private static final Pattern CURRENCY = Pattern.compile("[A-Z]{3}");
        private static final BigDecimal LIMIT = new BigDecimal("1000000.00");
        private final BigDecimal amount;
        private final String currency;

        private Money(BigDecimal amount, String currency) {
            if (amount == null) {
                throw new IllegalArgumentException("amount required");
            }
            if (currency == null || !CURRENCY.matcher(currency).matches()) {
                throw new IllegalArgumentException("currency must be three uppercase letters");
            }
            try {
                this.amount = amount.setScale(2, RoundingMode.UNNECESSARY);
            } catch (ArithmeticException cause) {
                throw new IllegalArgumentException("amount must have at most two decimal places", cause);
            }
            if (this.amount.abs().compareTo(LIMIT) > 0) {
                throw new IllegalArgumentException("amount outside supported range");
            }
            this.currency = currency;
        }

        static Money of(String amount, String currency) {
            if (amount == null) {
                throw new IllegalArgumentException("amount text required");
            }
            return new Money(new BigDecimal(amount), currency);
        }

        Money add(Money other) {
            if (other == null || !currency.equals(other.currency)) {
                throw new IllegalArgumentException("currencies must match");
            }
            return new Money(amount.add(other.amount), currency);
        }

        @Override
        public boolean equals(Object other) {
            return this == other
                    || other instanceof Money that
                    && amount.equals(that.amount)
                    && currency.equals(that.currency);
        }

        @Override
        public int hashCode() {
            return 31 * amount.hashCode() + currency.hashCode();
        }

        @Override
        public String toString() {
            return currency + " " + amount.toPlainString();
        }
    }

    static final class WorkOrderId {
        private static final Pattern CANONICAL = Pattern.compile(
                "WO-[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}");
        private final UUID value;

        private WorkOrderId(UUID value) {
            this.value = value;
        }

        static WorkOrderId parse(String text) {
            if (text == null || !CANONICAL.matcher(text).matches()) {
                throw new IllegalArgumentException("workOrderId must match WO-<uuid>");
            }
            return new WorkOrderId(UUID.fromString(text.substring(3)));
        }

        @Override
        public boolean equals(Object other) {
            return this == other || other instanceof WorkOrderId that && value.equals(that.value);
        }

        @Override
        public int hashCode() {
            return value.hashCode();
        }

        @Override
        public String toString() {
            return "WO-" + value;
        }
    }

    record ServiceTime(Instant scheduledAt, ZoneId displayZone) {
        ServiceTime {
            if (scheduledAt == null || displayZone == null) {
                throw new IllegalArgumentException("scheduledAt and displayZone required");
            }
        }

        ZonedDateTime localView() {
            return scheduledAt.atZone(displayZone);
        }

        boolean sameMomentAs(ServiceTime other) {
            return other != null && scheduledAt.equals(other.scheduledAt);
        }
    }

    public static void main(String[] args) {
        int assertions = 0;
        Money labor = Money.of("12.30", "CNY");
        Money normalized = Money.of("12.3", "CNY");
        Money total = labor.add(Money.of("2.70", "CNY"));
        assertions = check("CNY 12.30".equals(labor.toString()), "money format", assertions);
        assertions = check("CNY 15.00".equals(total.toString()), "money add", assertions);
        assertions = check(labor.equals(normalized), "normalized scale", assertions);
        assertions = check(labor.hashCode() == normalized.hashCode(), "equal hash", assertions);
        assertions = expectFailure(() -> Money.of("10.001", "CNY"), assertions);
        assertions = expectFailure(() -> labor.add(Money.of("1.00", "USD")), assertions);
        assertions = expectFailure(() -> Money.of("1.00", "cny"), assertions);
        assertions = expectFailure(() -> Money.of(null, "CNY"), assertions);
        assertions = expectFailure(() -> Money.of("1000000.01", "CNY"), assertions);

        String fixedText = "WO-550e8400-e29b-41d4-a716-446655440000";
        WorkOrderId id = WorkOrderId.parse(fixedText);
        WorkOrderId sameId = WorkOrderId.parse(id.toString());
        assertions = check(fixedText.equals(id.toString()), "canonical id", assertions);
        assertions = check(id.equals(sameId), "id round trip", assertions);
        assertions = check(id.hashCode() == sameId.hashCode(), "id equal hash", assertions);
        assertions = expectFailure(() -> WorkOrderId.parse("prefix-" + fixedText), assertions);
        assertions = expectFailure(() -> WorkOrderId.parse("WO-550e8400-e29b-41d4-a716-44665544000z"), assertions);
        assertions = expectFailure(() -> WorkOrderId.parse(null), assertions);

        Instant instant = Instant.parse("2026-07-16T01:00:00Z");
        ServiceTime shanghai = new ServiceTime(instant, ZoneId.of("Asia/Shanghai"));
        ServiceTime utc = new ServiceTime(instant, ZoneId.of("UTC"));
        assertions = check("2026-07-16T09:00+08:00[Asia/Shanghai]".equals(shanghai.localView().toString()),
                "shanghai view", assertions);
        assertions = check("2026-07-16T01:00Z[UTC]".equals(utc.localView().toString()),
                "utc view", assertions);
        assertions = check(shanghai.sameMomentAs(utc), "same instant", assertions);
        assertions = check(!shanghai.equals(utc), "zone participates in full value", assertions);
        assertions = expectFailure(() -> new ServiceTime(null, ZoneId.of("UTC")), assertions);

        System.out.println("money=" + labor);
        System.out.println("money.total=" + total);
        System.out.println("id=" + id);
        System.out.println("service.instant=" + instant);
        System.out.println("service.local=" + shanghai.localView());
        System.out.println("sameInstant.utc=" + shanghai.sameMomentAs(utc));
        System.out.println("assertions=" + assertions + " passed");
    }

    private static int expectFailure(Runnable action, int assertions) {
        try {
            action.run();
            throw new AssertionError("expected IllegalArgumentException");
        } catch (IllegalArgumentException expected) {
            return assertions + 1;
        }
    }

    private static int check(boolean condition, String message, int assertions) {
        if (!condition) {
            throw new AssertionError(message);
        }
        return assertions + 1;
    }
}
