package com.factorycare.workorder;

public final class StaticStateLab {
    private StaticStateLab() {
    }

    private static final class WorkOrderIdGenerator {
        private int next;

        WorkOrderIdGenerator(int first) {
            if (first < 1) {
                throw new IllegalArgumentException("first must be positive");
            }
            next = first;
        }

        String nextId(String siteCode) {
            if (!TextRules.hasText(siteCode)) {
                throw new IllegalArgumentException("siteCode must have text");
            }
            return "%s-%04d".formatted(siteCode, next++);
        }
    }

    private static final class WorkOrder {
        private static final String INITIAL_STATUS = "CREATED";

        private final String id;
        private final String category;
        private final String status;

        private WorkOrder(String id, String category) {
            this.id = id;
            this.category = category;
            status = INITIAL_STATUS;
        }

        static WorkOrder open(WorkOrderIdGenerator generator, String siteCode, String category) {
            if (!TextRules.hasText(category)) {
                throw new IllegalArgumentException("category must have text");
            }
            return new WorkOrder(generator.nextId(siteCode), category);
        }
    }

    private static final class TextRules {
        private TextRules() {
        }

        static boolean hasText(String value) {
            return value != null && !value.isBlank();
        }
    }

    public static void main(String[] args) {
        WorkOrderIdGenerator nc = new WorkOrderIdGenerator(1);
        WorkOrderIdGenerator nj = new WorkOrderIdGenerator(1);

        WorkOrder ncPump = WorkOrder.open(nc, "NC", "PUMP");
        WorkOrder njValve = WorkOrder.open(nj, "NJ", "VALVE");
        WorkOrder ncMotor = WorkOrder.open(nc, "NC", "MOTOR");

        int assertions = 0;
        assertions = check("NC-0001".equals(ncPump.id), "NC begins at one", assertions);
        assertions = check("NJ-0001".equals(njValve.id), "NJ begins independently", assertions);
        assertions = check("NC-0002".equals(ncMotor.id), "NC advances locally", assertions);
        assertions = check("PUMP".equals(ncPump.category), "factory keeps category", assertions);
        assertions = check("CREATED".equals(ncPump.status), "factory fixes initial status", assertions);
        assertions = check(ncPump != ncMotor, "factory creates new objects", assertions);
        assertions = check(TextRules.hasText("motor"), "text utility accepts text", assertions);
        assertions = check(!TextRules.hasText(null), "text utility rejects null", assertions);
        assertions = check(!TextRules.hasText("  "), "text utility rejects blank", assertions);
        assertions = expectIllegal(() -> new WorkOrderIdGenerator(0), "invalid first", assertions);
        assertions = expectIllegal(() -> nc.nextId(" "), "blank site", assertions);
        assertions = expectIllegal(() -> WorkOrder.open(nj, "NJ", null), "null category", assertions);

        WorkOrderIdGenerator replay = new WorkOrderIdGenerator(1);
        assertions = check("NC-0001".equals(replay.nextId("NC")), "fresh generator replays", assertions);
        assertions = check("NC-0003".equals(nc.nextId("NC")), "original generator retains own history", assertions);

        System.out.println("nc=" + ncPump.id + "," + ncMotor.id);
        System.out.println("nj=" + njValve.id);
        System.out.println("factory=" + ncPump.category + "|" + ncPump.status);
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

    @FunctionalInterface
    private interface Action {
        void run();
    }
}
