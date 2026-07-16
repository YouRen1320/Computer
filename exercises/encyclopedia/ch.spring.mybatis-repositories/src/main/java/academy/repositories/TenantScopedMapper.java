package academy.repositories;

import org.apache.ibatis.annotations.Param;
import org.apache.ibatis.annotations.Select;

/** Starter defect: tenantId is accepted but omitted from the SQL authorization boundary. */
public interface TenantScopedMapper {
    @Select("select tenant_id,id,status,version from work_order where id=#{id}")
    Object find(@Param("tenantId") String tenantId, @Param("id") String id);
}
