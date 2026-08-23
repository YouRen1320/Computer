import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalDateTime;
import java.time.ZoneId;
import java.util.TimeZone;
import java.util.UUID;
import java.util.regex.Pattern;

public final class BusinessValueChallenge {
    private BusinessValueChallenge() {
    }

    static final class Money {
        private final BigDecimal amount;

        Money(String amount) {
            // TODO：直接从十进制文本建立金额，并明确两位尺度政策；不要先转成 double。
            this.amount = new BigDecimal(Double.parseDouble(amount));
        }

        BigDecimal amount() {
            return amount;
        }
    }

    static final class WorkOrderId {
        private static final Pattern FORMAT = Pattern.compile("WO-.*");
        private final String text;

        private WorkOrderId(String text) {
            this.text = text;
        }

        static WorkOrderId parse(String text) {
            // TODO：限定每个 UUID 分组，并交给 UUID 解析器确认。
            if (text == null || !FORMAT.matcher(text).matches()) {
                throw new IllegalArgumentException("invalid work order id");
            }
            return new WorkOrderId(text);
        }

        @Override
        public String toString() {
            return text;
        }
    }

    static final class ServiceTime {
        static Instant fromLocal(LocalDateTime local, ZoneId zone) {
            // TODO：必须使用显式 zone；starter 故意仍读取机器默认时区。
            return local.atZone(ZoneId.systemDefault()).toInstant();
        }
    }

    public static void main(String[] args) {
        Money money = new Money("0.10");
        String actualAmount = money.amount().toPlainString();
        if (!"0.10".equals(actualAmount)) {
            System.err.println("STARTER_DOUBLE_MONEY expected=0.10 actual=" + actualAmount);
            System.exit(8);
        }

        if (accepts(() -> WorkOrderId.parse("WO-"))) {
            System.err.println("STARTER_LOOSE_REGEX input=WO- expected=false actual=true");
            System.exit(9);
        }

        TimeZone original = TimeZone.getDefault();
        try {
            LocalDateTime local = LocalDateTime.of(2026, 7, 16, 9, 0);
            TimeZone.setDefault(TimeZone.getTimeZone("UTC"));
            Instant utc = ServiceTime.fromLocal(local, ZoneId.of("Asia/Shanghai"));
            TimeZone.setDefault(TimeZone.getTimeZone("Asia/Shanghai"));
            Instant shanghai = ServiceTime.fromLocal(local, ZoneId.of("Asia/Shanghai"));
            if (!utc.equals(shanghai)) {
                System.err.println("STARTER_DEFAULT_ZONE utc=" + utc + " shanghai=" + shanghai);
                System.exit(10);
            }
        } finally {
            TimeZone.setDefault(original);
        }

        WorkOrderId id = WorkOrderId.parse("WO-550e8400-e29b-41d4-a716-446655440000");
        UUID parsed = UUID.fromString(id.toString().substring(3));
        int assertions = 0;
        assertions = check(new BigDecimal("0.10").compareTo(money.amount()) == 0, "decimal amount", assertions);
        assertions = check("550e8400-e29b-41d4-a716-446655440000".equals(parsed.toString()), "uuid parsed", assertions);
        assertions = check(!accepts(() -> WorkOrderId.parse("WO-")), "empty suffix rejected", assertions);
        assertions = check(!accepts(() -> WorkOrderId.parse("prefix-" + id)), "prefix rejected", assertions);
        assertions = check(!accepts(() -> WorkOrderId.parse(id + "-tail")), "suffix rejected", assertions);
        assertions = check(!accepts(() -> WorkOrderId.parse("WO-550e8400-e29b-41d4-a716-44665544000z")),
                "hex rejected", assertions);
        assertions = check("WO-550e8400-e29b-41d4-a716-446655440000".equals(id.toString()), "id format", assertions);
        assertions = check(parsed.version() == 4, "fixed uuid version", assertions);
        assertions = check(money.amount().scale() == 2, "money scale", assertions);
        assertions = check(money.amount().signum() >= 0, "money sign", assertions);
        assertions = check(!accepts(() -> WorkOrderId.parse(null)), "null id rejected", assertions);
        assertions = check(!accepts(() -> WorkOrderId.parse("")), "empty id rejected", assertions);
        assertions = check(!accepts(() -> WorkOrderId.parse("WO-550e8400e29b41d4a716446655440000")),
                "hyphens required", assertions);
        assertions = check(ZoneId.of("Asia/Shanghai") != null, "explicit zone available", assertions);
        assertions = check(Instant.parse("2026-07-16T01:00:00Z") != null, "fixed instant parsed", assertions);
        System.out.println("challenge.assertions=" + assertions + " passed");
    }

    private static boolean accepts(Runnable action) {
        try {
            action.run();
            return true;
        } catch (IllegalArgumentException expected) {
            return false;
        }
    }

    private static int check(boolean condition, String message, int assertions) {
        if (!condition) {
            throw new AssertionError(message);
        }
        return assertions + 1;
    }
}
