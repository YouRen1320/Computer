import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.Instant;
import java.time.LocalDateTime;
import java.time.ZoneId;
import java.time.ZonedDateTime;
import java.util.UUID;
import java.util.regex.Pattern;

public final class BusinessValueTypesLab {
    private BusinessValueTypesLab() {
    }

    static final class Money {
        private static final Pattern CURRENCY = Pattern.compile("[A-Z]{3}");
        private static final BigDecimal LIMIT = new BigDecimal("1000000.00");
        private final BigDecimal amount;
        private final String currency;

        private Money(BigDecimal normalized, String currency) {
            if (normalized == null || currency == null || !CURRENCY.matcher(currency).matches()) {
                throw new IllegalArgumentException("valid amount and currency required");
            }
            if (normalized.abs().compareTo(LIMIT) > 0) {
                throw new IllegalArgumentException("amount outside supported range");
            }
            this.amount = normalized;
            this.currency = currency;
        }

        static Money exact(String text, String currency) {
            if (text == null) {
                throw new IllegalArgumentException("amount text required");
            }
            try {
                return new Money(new BigDecimal(text).setScale(2, RoundingMode.UNNECESSARY), currency);
            } catch (ArithmeticException cause) {
                throw new IllegalArgumentException("amount must have at most two decimal places", cause);
            }
        }

        static Money settle(String text, String currency) {
            if (text == null) {
                throw new IllegalArgumentException("amount text required");
            }
            return new Money(new BigDecimal(text).setScale(2, RoundingMode.HALF_UP), currency);
        }

        Money add(Money other) {
            if (other == null || !currency.equals(other.currency)) {
                throw new IllegalArgumentException("currencies must match");
            }
            return new Money(amount.add(other.amount), currency);
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
        private static final Pattern TEXT = Pattern.compile(
                "WO-[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}");

        WorkOrderId {
            if (value == null) {
                throw new IllegalArgumentException("uuid required");
            }
        }

        static WorkOrderId parse(String text) {
            if (text == null || !TEXT.matcher(text).matches()) {
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
        Money rounded = Money.settle("19.995", "CNY");
        Money exact = Money.exact("20.00", "CNY");
        Money total = exact.add(Money.exact("2.50", "CNY"));
        assertions = check("CNY 20.00".equals(rounded.toString()), "half-up settlement", assertions);
        assertions = check("CNY 20.00".equals(exact.toString()), "exact amount", assertions);
        assertions = check("CNY 22.50".equals(total.toString()), "same currency add", assertions);
        assertions = check(exact.equals(Money.exact("20.0", "CNY")), "scale normalized", assertions);
        assertions = check(exact.hashCode() == Money.exact("20.0", "CNY").hashCode(), "equal hash", assertions);
        assertions = expectFailure(() -> Money.exact("1.001", "CNY"), assertions);
        assertions = expectFailure(() -> Money.exact("1.00", "cny"), assertions);
        assertions = expectFailure(() -> exact.add(Money.exact("1.00", "USD")), assertions);
        assertions = expectFailure(() -> Money.exact("1000000.01", "CNY"), assertions);

        String fixed = "WO-550e8400-e29b-41d4-a716-446655440000";
        WorkOrderId id = WorkOrderId.parse(fixed);
        WorkOrderId same = WorkOrderId.parse(id.toString());
        assertions = check(fixed.equals(id.toString()), "canonical id", assertions);
        assertions = check(id.equals(same), "round trip id", assertions);
        assertions = check(id.hashCode() == same.hashCode(), "id equal hash", assertions);
        assertions = expectFailure(() -> WorkOrderId.parse("WO-"), assertions);
        assertions = expectFailure(() -> WorkOrderId.parse("wo-550e8400-e29b-41d4-a716-446655440000"), assertions);
        assertions = expectFailure(() -> WorkOrderId.parse(fixed + "-tail"), assertions);
        assertions = expectFailure(() -> WorkOrderId.parse("WO-550e8400-e29b-41d4-a716-44665544000z"), assertions);

        Instant instant = Instant.parse("2026-07-16T01:00:00Z");
        ServiceTime shanghai = new ServiceTime(instant, ZoneId.of("Asia/Shanghai"));
        ServiceTime utc = new ServiceTime(instant, ZoneId.of("UTC"));
        ServiceTime fromLocal = ServiceTime.fromLocal(
                LocalDateTime.of(2026, 7, 16, 9, 0), ZoneId.of("Asia/Shanghai"));
        assertions = check("2026-07-16T09:00+08:00[Asia/Shanghai]".equals(shanghai.localView().toString()),
                "local view", assertions);
        assertions = check(shanghai.sameMomentAs(utc), "same instant across zones", assertions);
        assertions = check(!shanghai.equals(utc), "full values differ", assertions);
        assertions = check(instant.equals(fromLocal.scheduledAt()), "explicit local conversion", assertions);
        assertions = expectFailure(() -> ServiceTime.fromLocal(
                LocalDateTime.of(2026, 3, 29, 2, 30), ZoneId.of("Europe/Berlin")), assertions);
        assertions = expectFailure(() -> ServiceTime.fromLocal(
                LocalDateTime.of(2026, 10, 25, 2, 30), ZoneId.of("Europe/Berlin")), assertions);
        assertions = check(ServiceTime.fromLocal(LocalDateTime.of(2026, 2, 10, 9, 0),
                ZoneId.of("Europe/Berlin")) != null, "ordinary local time", assertions);
        assertions = expectFailure(() -> new ServiceTime(instant, null), assertions);

        System.out.println("report.money=INPUT 19.995 CNY | OP HALF_UP scale=2 | RESULT " + rounded);
        System.out.println("report.id=INPUT canonical text | OP regex+UUID parse | RESULT " + id);
        System.out.println("report.time=INPUT 2026-07-16T01:00:00Z Asia/Shanghai | OP atZone | RESULT "
                + shanghai.localView());
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
