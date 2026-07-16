package academy.repositories.adapter;

import academy.repositories.domain.WorkOrderRepository;
import academy.repositories.domain.WorkOrderRepository.*;
import java.util.Optional;
import org.apache.ibatis.annotations.*;
import org.springframework.dao.DataAccessException;

/** MyBatis adapter owns SQL, row DTOs, domain reconstruction, row-count semantics and exception translation. */
public final class MyBatisWorkOrderRepository implements WorkOrderRepository {
    private final WorkOrderMapper mapper;
    public MyBatisWorkOrderRepository(WorkOrderMapper mapper) { this.mapper = mapper; }

    @Override public Optional<WorkOrder> find(TenantId tenantId, WorkOrderId id) {
        try { return Optional.ofNullable(mapper.find(tenantId.value(), id.value())).map(MyBatisWorkOrderRepository::toDomain); }
        catch (DataAccessException failure) { throw new RepositoryUnavailableException(failure); }
    }

    @Override public void save(WorkOrder workOrder) {
        try {
            int rows = mapper.insert(workOrder.tenantId().value(), workOrder.id().value(), workOrder.status().name(), workOrder.version());
            if (rows != 1) throw new IllegalStateException("expected one inserted row, got " + rows);
        } catch (DataAccessException failure) { throw new RepositoryUnavailableException(failure); }
    }

    @Override public UpdateOutcome updateStatus(TenantId tenantId, WorkOrderId id, long expectedVersion, Status newStatus) {
        try {
            if (mapper.updateStatus(tenantId.value(), id.value(), expectedVersion, newStatus.name()) == 1) return UpdateOutcome.UPDATED;
            return mapper.find(tenantId.value(), id.value()) == null ? UpdateOutcome.NOT_FOUND : UpdateOutcome.VERSION_CONFLICT;
        } catch (DataAccessException failure) { throw new RepositoryUnavailableException(failure); }
    }

    private static WorkOrder toDomain(WorkOrderRow row) { return new WorkOrder(new TenantId(row.tenantId), new WorkOrderId(row.id), Status.valueOf(row.status), row.version); }

    @Mapper
    public interface WorkOrderMapper {
        @Select("select tenant_id, id, status, version from work_order where tenant_id=#{tenantId} and id=#{id}")
        WorkOrderRow find(@Param("tenantId") String tenantId, @Param("id") String id);
        @Insert("insert into work_order(tenant_id,id,status,version) values(#{tenantId},#{id},#{status},#{version})")
        int insert(@Param("tenantId") String tenantId, @Param("id") String id, @Param("status") String status, @Param("version") long version);
        @Update("update work_order set status=#{status}, version=version+1 where tenant_id=#{tenantId} and id=#{id} and version=#{expectedVersion}")
        int updateStatus(@Param("tenantId") String tenantId, @Param("id") String id, @Param("expectedVersion") long expectedVersion, @Param("status") String status);
    }

    public static final class WorkOrderRow {
        private String tenantId; private String id; private String status; private long version;
        public String getTenantId() { return tenantId; } public void setTenantId(String value) { tenantId = value; }
        public String getId() { return id; } public void setId(String value) { id = value; }
        public String getStatus() { return status; } public void setStatus(String value) { status = value; }
        public long getVersion() { return version; } public void setVersion(long value) { version = value; }
    }
}
