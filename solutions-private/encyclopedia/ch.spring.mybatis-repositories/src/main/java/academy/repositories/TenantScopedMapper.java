package academy.repositories;

import org.apache.ibatis.annotations.Param;
import org.apache.ibatis.annotations.Select;

/** Proven answer: tenant and aggregate ID are both mandatory bound parameters. */
public interface TenantScopedMapper {
    @Select("select tenant_id,id,status,version from work_order where tenant_id=#{tenantId} and id=#{id}")
    Object find(@Param("tenantId") String tenantId, @Param("id") String id);
}
