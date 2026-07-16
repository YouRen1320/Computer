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
            String utc = local.atZone(ZoneId.systemDefault()).toInstant().toString();
            TimeZone.setDefault(TimeZone.getTimeZone("Asia/Shanghai"));
            String shanghai = local.atZone(ZoneId.systemDefault()).toInstant().toString();
            if (!utc.equals(shanghai)) {
                System.err.println("DEFAULT_ZONE_DRIFT utc=" + utc + " shanghai=" + shanghai);
                System.exit(6);
            }
            throw new AssertionError("fixture did not expose default-zone drift");
        } finally {
            TimeZone.setDefault(original);
        }
    }
}
