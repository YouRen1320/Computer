public final class ClassStateDemo {
    private ClassStateDemo() {
    }

    private static final class Ticket {
        private static final String PREFIX = "FC-";
        private static int createdCount;

        private final int number;
        private final String category;

        private Ticket(String category) {
            if (!TextRules.hasText(category)) {
                throw new IllegalArgumentException("category must have text");
            }
            createdCount++;
            number = createdCount;
            this.category = category;
        }

        static Ticket open(String category) {
            return new Ticket(category);
        }

        static int createdCount() {
            return createdCount;
        }

        String label() {
            return PREFIX + number + ":" + category;
        }
    }

    private static final class TextRules {
        private TextRules() {
        }

        static boolean hasText(String value) {
            return value != null && !value.isBlank();
        }
    }

    private static final class InitTrace {
        private static String trace = "";
        private static int first = mark("1", 10);
        private static int second;

        static {
            trace += "B";
            second = 20;
        }

        private static int third = mark("3", 30);

        private InitTrace() {
        }

        private static int mark(String token, int value) {
            trace += token;
            return value;
        }

        static String snapshot() {
            return trace + "|" + first + "|" + second + "|" + third;
        }
    }

    public static void main(String[] args) {
        Ticket pump = Ticket.open("PUMP");
        Ticket valve = Ticket.open("VALVE");

        check("FC-1:PUMP".equals(pump.label()), "first instance owns number 1");
        check("FC-2:VALVE".equals(valve.label()), "second instance owns number 2");
        check(Ticket.createdCount() == 2, "class count is shared");
        check(!TextRules.hasText(null), "null has no text");
        check(!TextRules.hasText("  "), "blank has no text");
        check(TextRules.hasText("motor"), "ordinary text passes");
        check("1B3|10|20|30".equals(InitTrace.snapshot()), "static initialization is textual");
        check(pump != valve, "factory returns independent instances");

        System.out.println("first=" + pump.label());
        System.out.println("second=" + valve.label());
        System.out.println("created=" + Ticket.createdCount());
        System.out.println("init=" + InitTrace.snapshot());
        System.out.println("assertions=8 passed");
    }

    private static void check(boolean condition, String message) {
        if (!condition) {
            throw new AssertionError(message);
        }
    }
}
