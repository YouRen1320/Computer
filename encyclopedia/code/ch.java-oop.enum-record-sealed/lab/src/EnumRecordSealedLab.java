public final class EnumRecordSealedLab {
    private EnumRecordSealedLab() {
    }

    enum WorkOrderStatus {
        CREATED, TRIAGED, ASSIGNED, ACCEPTED, IN_PROGRESS, PENDING_PARTS,
        PENDING_APPROVAL, RESOLVED, VERIFIED, CLOSED, REOPENED, CANCELLED;

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

    sealed interface WorkOrderCommand permits AssignCommand, StartCommand, ResolveCommand {
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

    record ResolveCommand(String workOrderId, String resolution) implements WorkOrderCommand {
        ResolveCommand {
            requireText(workOrderId, "workOrderId");
            requireText(resolution, "resolution");
        }
    }

    public static void main(String[] args) {
        int assertions = 0;
        assertions = check(WorkOrderStatus.values().length == 12, "status count", assertions);
        assertions = check(WorkOrderStatus.valueOf("PENDING_APPROVAL") == WorkOrderStatus.PENDING_APPROVAL, "parse", assertions);
        assertions = check(WorkOrderStatus.CLOSED.isTerminal(), "closed", assertions);
        assertions = check(WorkOrderStatus.CANCELLED.isTerminal(), "cancelled", assertions);
        assertions = check(!WorkOrderStatus.VERIFIED.isTerminal(), "verified", assertions);

        EquipmentCoordinate first = new EquipmentCoordinate(" NC-FACTORY ", 2, 9);
        EquipmentCoordinate second = new EquipmentCoordinate("NC-FACTORY", 2, 9);
        EquipmentCoordinate other = new EquipmentCoordinate("NC-FACTORY", 2, 10);
        assertions = check(first != second, "identity", assertions);
        assertions = check(first.equals(second), "value", assertions);
        assertions = check(second.equals(first), "symmetric", assertions);
        assertions = check(first.hashCode() == second.hashCode(), "hash", assertions);
        assertions = check("NC-FACTORY".equals(first.site()), "normalized", assertions);
        assertions = check(!first.equals(other), "different slot", assertions);
        assertions = expectInvalidSite(assertions);
        assertions = expectInvalidAisle(assertions);

        String assign = summarize(new AssignCommand("WO-2001", "TECH-09"));
        String start = summarize(new StartCommand("WO-2001", "TECH-09"));
        String resolve = summarize(new ResolveCommand("WO-2001", "seal replaced"));
        assertions = check("ASSIGN|WO-2001|TECH-09".equals(assign), "assign", assertions);
        assertions = check("START|WO-2001|TECH-09".equals(start), "start", assertions);
        assertions = check("RESOLVE|WO-2001|seal replaced".equals(resolve), "resolve", assertions);
        assertions = expectNullCommand(assertions);

        System.out.println("status.count=" + WorkOrderStatus.values().length);
        System.out.println("terminal=" + WorkOrderStatus.CLOSED + "," + WorkOrderStatus.CANCELLED);
        System.out.println("coordinate=" + first);
        System.out.println("command.assign=" + assign);
        System.out.println("command.start=" + start);
        System.out.println("command.resolve=" + resolve);
        System.out.println("assertions=" + assertions + " passed");
    }

    static String summarize(WorkOrderCommand command) {
        if (command == null) {
            throw new IllegalArgumentException("command required");
        }
        return switch (command) {
            case AssignCommand assign -> "ASSIGN|" + assign.workOrderId() + "|" + assign.technicianId();
            case StartCommand start -> "START|" + start.workOrderId() + "|" + start.actorId();
            case ResolveCommand resolve -> "RESOLVE|" + resolve.workOrderId() + "|" + resolve.resolution();
        };
    }

    private static int expectInvalidSite(int assertions) {
        try {
            new EquipmentCoordinate(" ", 1, 1);
            throw new AssertionError("blank site must fail");
        } catch (IllegalArgumentException expected) {
            return assertions + 1;
        }
    }

    private static int expectInvalidAisle(int assertions) {
        try {
            new EquipmentCoordinate("NC-FACTORY", 0, 1);
            throw new AssertionError("invalid aisle must fail");
        } catch (IllegalArgumentException expected) {
            return assertions + 1;
        }
    }

    private static int expectNullCommand(int assertions) {
        try {
            summarize(null);
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
