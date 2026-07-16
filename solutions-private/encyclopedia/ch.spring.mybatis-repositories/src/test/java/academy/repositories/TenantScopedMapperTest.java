package academy.repositories;

import org.apache.ibatis.annotations.Select;
import org.junit.jupiter.api.Test;
import static org.assertj.core.api.Assertions.assertThat;

class TenantScopedMapperTest {
    private static String sql() throws Exception { return TenantScopedMapper.class.getMethod("find",String.class,String.class).getAnnotation(Select.class).value()[0].replaceAll("\\s+","").toLowerCase(); }
    @Test void queryBindsWorkOrderId() throws Exception { assertThat(sql()).contains("id=#{id}"); }
    @Test void queryBindsTenant() throws Exception { assertThat(sql()).as("EXPECTED_TENANT_PREDICATE").contains("tenant_id=#{tenantid}"); }
}
