public final class EnumRecordSealedDemo {
    private EnumRecordSealedDemo() {
    }

    enum WorkOrderStatus {
        CREATED,
        TRIAGED,
        ASSIGNED,
        ACCEPTED,
        IN_PROGRESS,
        PENDING_PARTS,
        PENDING_APPROVAL,
        RESOLVED,
        VERIFIED,
        CLOSED,
        REOPENED,
        CANCELLED;

        boolean isTerminal() {
            return this == CLOSED || this == CANCELLED;
        }
    }

    record EquipmentCoordinate(String site, int aisle, int slot) {
        EquipmentCoordinate {
            if (site == null || site.isBlank()) {
                throw new IllegalArgumentException("site must have text");
            }
            site = site.trim();
            if (aisle < 1 || slot < 1) {
                throw new IllegalArgumentException("aisle and slot must be positive");
            }
        }
    }

    sealed interface WorkOrderCommand permits AssignCommand, StartCommand, CloseCommand {
    }

    record AssignCommand(String workOrderId, String technicianId) implements WorkOrderCommand {
        AssignCommand {
            requireText(workOrderId, "workOrderId");
            requireText(technicianId, "technicianId");
        }
    }

    record StartCommand(String workOrderId, String actorId) implements WorkOrderCommand {
        StartCommand {
            requireText(workOrderId, "workOrderId");
            requireText(actorId, "actorId");
        }
    }

    record CloseCommand(String workOrderId, String resolution) implements WorkOrderCommand {
        CloseCommand {
            requireText(workOrderId, "workOrderId");
            requireText(resolution, "resolution");
        }
    }

    public static void main(String[] args) {
        int assertions = 0;
        WorkOrderStatus parsed = WorkOrderStatus.valueOf("IN_PROGRESS");
        assertions = check(WorkOrderStatus.values().length == 12, "twelve statuses", assertions);
        assertions = check(parsed == WorkOrderStatus.IN_PROGRESS, "exact enum parse", assertions);
        assertions = check(WorkOrderStatus.CLOSED.isTerminal(), "closed terminal", assertions);
        assertions = check(WorkOrderStatus.CANCELLED.isTerminal(), "cancelled terminal", assertions);
        assertions = check(!WorkOrderStatus.VERIFIED.isTerminal(), "verified not terminal", assertions);

        EquipmentCoordinate first = new EquipmentCoordinate(" NC-1 ", 3, 7);
        EquipmentCoordinate second = new EquipmentCoordinate("NC-1", 3, 7);
        assertions = check(first != second, "record identity differs", assertions);
        assertions = check(first.equals(second), "record value equal", assertions);
        assertions = check(first.hashCode() == second.hashCode(), "record equal hash", assertions);
        assertions = check("NC-1".equals(first.site()), "compact constructor normalized", assertions);
        assertions = expectInvalidCoordinate(assertions);

        String assign = describe(new AssignCommand("WO-1001", "TECH-07"));
        String start = describe(new StartCommand("WO-1001", "TECH-07"));
        String close = describe(new CloseCommand("WO-1001", "bearing replaced"));
        assertions = check("ASSIGN|WO-1001|TECH-07".equals(assign), "assign branch", assertions);
        assertions = check("START|WO-1001|TECH-07".equals(start), "start branch", assertions);
        assertions = check("CLOSE|WO-1001|bearing replaced".equals(close), "close branch", assertions);
        assertions = expectNullCommand(assertions);

        System.out.println("status=" + parsed);
        System.out.println("terminal.closed=" + WorkOrderStatus.CLOSED.isTerminal());
        System.out.println("coordinate=" + first);
        System.out.println("coordinate.equal=" + first.equals(second));
        System.out.println("command.assign=" + assign);
        System.out.println("command.start=" + start);
        System.out.println("command.close=" + close);
        System.out.println("assertions=" + assertions + " passed");
    }

    static String describe(WorkOrderCommand command) {
        if (command == null) {
            throw new IllegalArgumentException("command required");
        }
        return switch (command) {
            case AssignCommand assign -> "ASSIGN|" + assign.workOrderId() + "|" + assign.technicianId();
            case StartCommand start -> "START|" + start.workOrderId() + "|" + start.actorId();
            case CloseCommand close -> "CLOSE|" + close.workOrderId() + "|" + close.resolution();
        };
    }

    private static int expectInvalidCoordinate(int assertions) {
        try {
            new EquipmentCoordinate("NC-1", 0, 7);
            throw new AssertionError("invalid aisle must fail");
        } catch (IllegalArgumentException expected) {
            return assertions + 1;
        }
    }

    private static int expectNullCommand(int assertions) {
        try {
            describe(null);
            throw new AssertionError("null command must fail");
        } catch (IllegalArgumentException expected) {
            return assertions + 1;
        }
    }

    private static void requireText(String value, String field) {
        if (value == null || value.isBlank()) {
            throw new IllegalArgumentException(field + " must have text");
        }
    }

    private static int check(boolean condition, String message, int assertions) {
        if (!condition) {
            throw new AssertionError(message);
        }
        return assertions + 1;
    }
}
