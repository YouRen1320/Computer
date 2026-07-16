import java.time.LocalDateTime;
import java.time.ZoneId;
import java.util.TimeZone;

public final class DefaultZoneFailure {
    private DefaultZoneFailure() {
    }

    public static void main(String[] args) {
        TimeZone original = TimeZone.getDefault();
        try {
            LocalDateTime local = LocalDateTime.of(2026, 7, 16, 9, 0);
            TimeZone.setDefault(TimeZone.getTimeZone("UTC"));
            String first = local.atZone(ZoneId.systemDefault()).toInstant().toString();
            TimeZone.setDefault(TimeZone.getTimeZone("Asia/Shanghai"));
            String second = local.atZone(ZoneId.systemDefault()).toInstant().toString();
            if (!first.equals(second)) {
                System.err.println("DEFAULT_ZONE_DRIFT utc=" + first + " shanghai=" + second);
                System.exit(6);
            }
            throw new AssertionError("fixture did not expose the default-zone dependency");
        } finally {
            TimeZone.setDefault(original);
        }
    }
}
