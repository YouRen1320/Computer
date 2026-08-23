package academy.usecases.domain;

import java.util.Objects;

/** Aggregate owns assignment state and optimistic-version invariants. */
public final class WorkOrder {
    public enum State { TRIAGED, ASSIGNED }
    private final String tenantId; private final String id; private State state; private long version; private String teamId; private String technicianId;
    public WorkOrder(String tenantId,String id,State state,long version){this.tenantId=required(tenantId);this.id=required(id);this.state=Objects.requireNonNull(state);if(version<0)throw new IllegalArgumentException("version");this.version=version;}
    public void assign(String teamId,String technicianId,long expectedVersion){if(state!=State.TRIAGED)throw new IllegalStateException("work order is not triaged");if(version!=expectedVersion)throw new VersionConflict();this.teamId=required(teamId);this.technicianId=required(technicianId);state=State.ASSIGNED;version++;}
    private static String required(String value){if(value==null||value.isBlank())throw new IllegalArgumentException("required");return value;}
    public String tenantId(){return tenantId;} public String id(){return id;} public State state(){return state;} public long version(){return version;} public String teamId(){return teamId;} public String technicianId(){return technicianId;}
    public static final class VersionConflict extends RuntimeException {}
}
