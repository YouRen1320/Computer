package academy.repositories.adapter;

import academy.repositories.domain.WorkOrderRepository;
import academy.repositories.domain.WorkOrderRepository.*;
import java.util.Optional;
import org.apache.ibatis.annotations.*;
import org.springframework.dao.DataAccessException;

/** Adapter owns all mapper SQL, technical rows, reconstruction and failure translation. */
public final class MyBatisWorkOrderRepository implements WorkOrderRepository {
    private final WorkOrderMapper mapper;
    public MyBatisWorkOrderRepository(WorkOrderMapper mapper) { this.mapper = mapper; }
    @Override public Optional<WorkOrder> find(TenantId tenantId, WorkOrderId id) { try { return Optional.ofNullable(mapper.find(tenantId.value(),id.value())).map(MyBatisWorkOrderRepository::domain); } catch (DataAccessException e) { throw new RepositoryUnavailableException(e); } }
    @Override public void save(WorkOrder workOrder) { try { if (mapper.insert(workOrder.tenantId().value(),workOrder.id().value(),workOrder.status().name(),workOrder.version()) != 1) throw new IllegalStateException("insert row count"); } catch (DataAccessException e) { throw new RepositoryUnavailableException(e); } }
    @Override public UpdateOutcome updateStatus(TenantId tenantId, WorkOrderId id, long expectedVersion, Status status) { try { if (mapper.update(tenantId.value(),id.value(),expectedVersion,status.name()) == 1) return UpdateOutcome.UPDATED; return mapper.find(tenantId.value(),id.value()) == null ? UpdateOutcome.NOT_FOUND : UpdateOutcome.VERSION_CONFLICT; } catch (DataAccessException e) { throw new RepositoryUnavailableException(e); } }
    private static WorkOrder domain(WorkOrderRow row) { return new WorkOrder(new TenantId(row.tenantId),new WorkOrderId(row.id),Status.valueOf(row.status),row.version); }

    @Mapper public interface WorkOrderMapper {
        @Select("select tenant_id,id,status,version from work_order where tenant_id=#{tenantId} and id=#{id}") WorkOrderRow find(@Param("tenantId") String tenantId,@Param("id") String id);
        @Insert("insert into work_order(tenant_id,id,status,version) values(#{tenantId},#{id},#{status},#{version})") int insert(@Param("tenantId") String tenantId,@Param("id") String id,@Param("status") String status,@Param("version") long version);
        @Update("update work_order set status=#{status},version=version+1 where tenant_id=#{tenantId} and id=#{id} and version=#{expectedVersion}") int update(@Param("tenantId") String tenantId,@Param("id") String id,@Param("expectedVersion") long expectedVersion,@Param("status") String status);
    }
    public static final class WorkOrderRow {
        private String tenantId; private String id; private String status; private long version;
        public String getTenantId(){return tenantId;} public void setTenantId(String v){tenantId=v;} public String getId(){return id;} public void setId(String v){id=v;} public String getStatus(){return status;} public void setStatus(String v){status=v;} public long getVersion(){return version;} public void setVersion(long v){version=v;}
    }
}
