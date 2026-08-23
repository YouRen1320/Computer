package academy.domain;

import java.util.EnumSet;
import java.util.Locale;
import java.util.Objects;
import java.util.UUID;

public final class DomainFixtures {
    private DomainFixtures() {
    }

    public record WorkOrderId(UUID value) {
        public WorkOrderId {
            Objects.requireNonNull(value, "workOrderId");
        }

        public static WorkOrderId parse(String value) {
            return new WorkOrderId(UUID.fromString(value));
        }
    }

    public record AssetCode(String value) {
        public AssetCode {
            Objects.requireNonNull(value, "assetCode");
            value = value.strip().toUpperCase(Locale.ROOT);
            if (!value.matches("[A-Z0-9-]{3,32}")) {
                throw new IllegalArgumentException("assetCode must be 3-32 letters, digits, or hyphens");
            }
        }
    }

    public record TeamId(String value) {
        public TeamId {
            Objects.requireNonNull(value, "teamId");
            value = value.strip().toUpperCase(Locale.ROOT);
            if (!value.matches("[A-Z0-9-]{2,24}")) {
                throw new IllegalArgumentException("teamId must be 2-24 letters, digits, or hyphens");
            }
        }
    }

    public enum WorkOrderStatus {
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
        CANCELLED
    }

    public enum Command {
        TRIAGE,
        ASSIGN,
        ACCEPT,
        START,
        RESOLVE,
        VERIFY,
        CLOSE
    }

    public static final class InvalidTransition extends IllegalStateException {
        private final WorkOrderStatus current;
        private final Command command;

        public InvalidTransition(WorkOrderStatus current, Command command) {
            super("Cannot " + command + " from " + current);
            this.current = current;
            this.command = command;
        }

        public WorkOrderStatus current() {
            return current;
        }

        public Command command() {
            return command;
        }
    }

    public record Snapshot(WorkOrderStatus status, TeamId teamId, long version) {
    }

    public static final class WorkOrder {
        private static final EnumSet<WorkOrderStatus> REQUIRES_TEAM = EnumSet.of(
                WorkOrderStatus.ASSIGNED,
                WorkOrderStatus.ACCEPTED,
                WorkOrderStatus.IN_PROGRESS,
                WorkOrderStatus.PENDING_PARTS,
                WorkOrderStatus.PENDING_APPROVAL,
                WorkOrderStatus.RESOLVED,
                WorkOrderStatus.VERIFIED,
                WorkOrderStatus.CLOSED,
                WorkOrderStatus.REOPENED);

        private final WorkOrderId id;
        private final AssetCode assetCode;
        private WorkOrderStatus status;
        private TeamId teamId;
        private long version;

        private WorkOrder(WorkOrderId id, AssetCode assetCode) {
            this.id = Objects.requireNonNull(id, "id");
            this.assetCode = Objects.requireNonNull(assetCode, "assetCode");
            this.status = WorkOrderStatus.CREATED;
            this.version = 0;
            assertInvariant();
        }

        public static WorkOrder create(WorkOrderId id, AssetCode assetCode) {
            return new WorkOrder(id, assetCode);
        }

        public WorkOrderId id() {
            return id;
        }

        public AssetCode assetCode() {
            return assetCode;
        }

        public WorkOrderStatus status() {
            return status;
        }

        public TeamId teamId() {
            return teamId;
        }

        public long version() {
            return version;
        }

        public Snapshot snapshot() {
            return new Snapshot(status, teamId, version);
        }

        public void triage() {
            transition(WorkOrderStatus.CREATED, WorkOrderStatus.TRIAGED, Command.TRIAGE);
        }

        public void assign(TeamId teamId) {
            require(WorkOrderStatus.TRIAGED, Command.ASSIGN);
            this.teamId = Objects.requireNonNull(teamId, "teamId");
            this.status = WorkOrderStatus.ASSIGNED;
            this.version++;
            assertInvariant();
        }

        public void accept() {
            transition(WorkOrderStatus.ASSIGNED, WorkOrderStatus.ACCEPTED, Command.ACCEPT);
        }

        public void start() {
            transition(WorkOrderStatus.ACCEPTED, WorkOrderStatus.IN_PROGRESS, Command.START);
        }

        public void resolve() {
            transition(WorkOrderStatus.IN_PROGRESS, WorkOrderStatus.RESOLVED, Command.RESOLVE);
        }

        public void verify() {
            transition(WorkOrderStatus.RESOLVED, WorkOrderStatus.VERIFIED, Command.VERIFY);
        }

        public void close() {
            transition(WorkOrderStatus.VERIFIED, WorkOrderStatus.CLOSED, Command.CLOSE);
        }

        private void transition(
                WorkOrderStatus expected,
                WorkOrderStatus target,
                Command command) {
            require(expected, command);
            status = target;
            version++;
            assertInvariant();
        }

        private void require(WorkOrderStatus expected, Command command) {
            if (status != expected) {
                throw new InvalidTransition(status, command);
            }
        }

        private void assertInvariant() {
            if (id == null || assetCode == null || status == null || version < 0) {
                throw new IllegalStateException("WorkOrder core invariant violated");
            }
            if (REQUIRES_TEAM.contains(status) && teamId == null) {
                throw new IllegalStateException("Assigned lifecycle requires a team");
            }
        }

        @Override
        public boolean equals(Object other) {
            return this == other
                    || other instanceof WorkOrder workOrder && id.equals(workOrder.id);
        }

        @Override
        public int hashCode() {
            return id.hashCode();
        }
    }
}
