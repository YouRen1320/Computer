public class LateValidationFailure {
    public static void main(String[] args) {
        try {
            new Device(" ");
        } catch (IllegalArgumentException expected) {
            // Inspect the deliberately published half-object below.
        }
        if (Device.published != null && " ".equals(Device.published.code)) {
            System.err.println("LATE_VALIDATION leaked_code=<blank> published=true");
            System.exit(6);
        }
        throw new AssertionError("fault was not reproduced");
    }

    static final class Device {
        static Device published;
        private String code;

        Device(String code) {
            this.code = code;
            published = this;
            if (code == null || code.trim().isEmpty()) {
                throw new IllegalArgumentException("invalid code");
            }
        }
    }
}
