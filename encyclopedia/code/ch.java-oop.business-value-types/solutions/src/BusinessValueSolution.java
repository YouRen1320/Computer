import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.Instant;
import java.time.LocalDateTime;
import java.time.ZoneId;
import java.time.ZonedDateTime;
import java.util.UUID;
import java.util.regex.Pattern;

public final class BusinessValueSolution {
    private BusinessValueSolution() {
    }

    static final class Money {
        private static final Pattern CURRENCY = Pattern.compile("[A-Z]{3}");
        private final BigDecimal amount;
        private final String currency;

        private Money(BigDecimal amount, String currency) {
            if (amount == null || currency == null || !CURRENCY.matcher(currency).matches()) {
                throw new IllegalArgumentException("valid amount and currency required");
            }
            try {
                this.amount = amount.setScale(2, RoundingMode.UNNECESSARY);
            } catch (ArithmeticException cause) {
                throw new IllegalArgumentException("amount must have at most two decimal places", cause);
            }
            this.currency = currency;
        }

        static Money of(String text, String currency) {
            if (text == null) {
                throw new IllegalArgumentException("amount text required");
            }
            return new Money(new BigDecimal(text), currency);
        }

        @Override
        public boolean equals(Object other) {
            return this == other || other instanceof Money that
                    && amount.equals(that.amount) && currency.equals(that.currency);
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

    record WorkOrderId(UUID value) {
        private static final Pattern CANONICAL = Pattern.compile(
                "WO-[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}");

        WorkOrderId {
            if (value == null) {
                throw new IllegalArgumentException("uuid required");
            }
        }

        static WorkOrderId parse(String text) {
            if (text == null || !CANONICAL.matcher(text).matches()) {
                throw new IllegalArgumentException("workOrderId must match WO-<uuid>");
            }
            return new WorkOrderId(UUID.fromString(text.substring(3)));
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

        static ServiceTime fromLocal(LocalDateTime local, ZoneId zone) {
            if (local == null || zone == null || zone.getRules().getValidOffsets(local).size() != 1) {
                throw new IllegalArgumentException("local time must resolve to exactly one offset");
            }
            return new ServiceTime(local.atZone(zone).toInstant(), zone);
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
        Money money = Money.of("20.00", "CNY");
        Money normalized = Money.of("20.0", "CNY");
        assertions = check("CNY 20.00".equals(money.toString()), "money format", assertions);
        assertions = check(money.toString().endsWith("20.00"), "money scale", assertions);
        assertions = check(money.equals(normalized), "money equality", assertions);
        assertions = check(money.hashCode() == normalized.hashCode(), "money equal hash", assertions);
        assertions = expectFailure(() -> Money.of("1.001", "CNY"), assertions);
        assertions = expectFailure(() -> Money.of("1.00", "cny"), assertions);

        String text = "WO-550e8400-e29b-41d4-a716-446655440000";
        WorkOrderId id = WorkOrderId.parse(text);
        WorkOrderId sameId = WorkOrderId.parse(id.toString());
        assertions = check(text.equals(id.toString()), "id canonical", assertions);
        assertions = check(id.equals(sameId), "id equality", assertions);
        assertions = check(id.hashCode() == sameId.hashCode(), "id equal hash", assertions);
        assertions = expectFailure(() -> WorkOrderId.parse("WO-"), assertions);
        assertions = expectFailure(() -> WorkOrderId.parse(text + "-tail"), assertions);
        assertions = expectFailure(() -> WorkOrderId.parse("WO-550e8400-e29b-41d4-a716-44665544000z"), assertions);

        Instant instant = Instant.parse("2026-07-16T01:00:00Z");
        ServiceTime shanghai = new ServiceTime(instant, ZoneId.of("Asia/Shanghai"));
        ServiceTime utc = new ServiceTime(instant, ZoneId.of("UTC"));
        ServiceTime fromLocal = ServiceTime.fromLocal(LocalDateTime.of(2026, 7, 16, 9, 0),
                ZoneId.of("Asia/Shanghai"));
        assertions = check("2026-07-16T09:00+08:00[Asia/Shanghai]".equals(shanghai.localView().toString()),
                "local view", assertions);
        assertions = check(shanghai.sameMomentAs(utc), "same moment", assertions);
        assertions = check(!shanghai.equals(utc), "zone participates", assertions);
        assertions = check(instant.equals(fromLocal.scheduledAt()), "explicit local conversion", assertions);
        assertions = expectFailure(() -> ServiceTime.fromLocal(LocalDateTime.of(2026, 3, 29, 2, 30),
                ZoneId.of("Europe/Berlin")), assertions);
        assertions = expectFailure(() -> new ServiceTime(instant, null), assertions);

        System.out.println("solution.money=" + money);
        System.out.println("solution.id=" + id);
        System.out.println("solution.local=" + shanghai.localView());
        System.out.println("solution.assertions=" + assertions + " passed");
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
