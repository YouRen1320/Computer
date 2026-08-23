package academy.domainexercise;

public final class StatusBypass {
    private StatusBypass() {
    }

    public enum Status {
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

    public static final class WorkOrder {
        private Status status = Status.CREATED;

        public Status status() {
            return status;
        }

        public void triage() {
            require(Status.CREATED);
            status = Status.TRIAGED;
        }

        public void assign() {
            require(Status.TRIAGED);
            status = Status.ASSIGNED;
        }

        private void require(Status expected) {
            if (status != expected) {
                throw new IllegalStateException("Expected " + expected + " but was " + status);
            }
        }
    }
}
