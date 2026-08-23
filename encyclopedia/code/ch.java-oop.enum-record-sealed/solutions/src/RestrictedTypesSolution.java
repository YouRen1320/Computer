public final class RestrictedTypesSolution {
    enum WorkOrderStatus {
        CREATED, TRIAGED, ASSIGNED, ACCEPTED, IN_PROGRESS, PENDING_PARTS,
        PENDING_APPROVAL, RESOLVED, VERIFIED, CLOSED, REOPENED, CANCELLED
    }

    record EquipmentCoordinate(String site, int aisle, int slot) {
        EquipmentCoordinate {
            if (site == null || site.isBlank()) throw new IllegalArgumentException("site required");
            site = site.trim();
            if (aisle < 1 || slot < 1) throw new IllegalArgumentException("positive location required");
        }
    }

    sealed interface Command permits AssignCommand, StartCommand, CloseCommand { }
    record AssignCommand(String technicianId) implements Command { }
    record StartCommand(String actorId) implements Command { }
    record CloseCommand(String resolution) implements Command { }

    static String describe(Command command) {
        if (command == null) throw new IllegalArgumentException("command required");
        return switch (command) {
            case AssignCommand assign -> "ASSIGN|" + assign.technicianId();
            case StartCommand start -> "START|" + start.actorId();
            case CloseCommand close -> "CLOSE|" + close.resolution();
        };
    }

    public static void main(String[] args) {
        int assertions = 0;
        assertions = check(WorkOrderStatus.values().length == 12, "status count", assertions);
        assertions = check(WorkOrderStatus.valueOf("IN_PROGRESS") == WorkOrderStatus.IN_PROGRESS, "parse", assertions);
        EquipmentCoordinate first = new EquipmentCoordinate(" NC-1 ", 3, 7);
        EquipmentCoordinate second = new EquipmentCoordinate("NC-1", 3, 7);
        assertions = check("NC-1".equals(first.site()), "normalize", assertions);
        assertions = check(first != second, "identity", assertions);
        assertions = check(first.equals(second), "value", assertions);
        assertions = check(first.hashCode() == second.hashCode(), "hash", assertions);
        assertions = expectInvalidCoordinate(assertions);
        assertions = check("ASSIGN|TECH-07".equals(describe(new AssignCommand("TECH-07"))), "assign", assertions);
        assertions = check("START|TECH-07".equals(describe(new StartCommand("TECH-07"))), "start", assertions);
        assertions = check("CLOSE|bearing replaced".equals(describe(new CloseCommand("bearing replaced"))), "close", assertions);
        assertions = check(!first.equals(new EquipmentCoordinate("NC-1", 3, 8)), "different", assertions);
        assertions = check(first.toString().contains("site=NC-1"), "debug text", assertions);
        assertions = check(WorkOrderStatus.CLOSED != WorkOrderStatus.CANCELLED, "distinct", assertions);
        assertions = check(WorkOrderStatus.CANCELLED.name().equals("CANCELLED"), "name", assertions);

        System.out.println("solution.statusCount=" + WorkOrderStatus.values().length);
        System.out.println("solution.coordinate=" + first);
        System.out.println("solution.close=" + describe(new CloseCommand("bearing replaced")));
        System.out.println("solution.assertions=" + assertions + " passed");
    }

    private static int expectInvalidCoordinate(int assertions) {
        try {
            new EquipmentCoordinate(" ", 0, 0);
            throw new AssertionError("invalid coordinate must fail");
        } catch (IllegalArgumentException expected) {
            return assertions + 1;
        }
    }

    private static int check(boolean condition, String message, int assertions) {
        if (!condition) throw new AssertionError(message);
        return assertions + 1;
    }
}
