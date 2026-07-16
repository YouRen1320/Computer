package com.factorycare.workorder.persistence;

import java.util.List;
import java.util.Optional;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;

/** SQL-led persistence boundary; business transactions remain owned by the service layer. */
@Mapper
public interface WorkOrderMapper {
  Optional<WorkOrderRow> findById(@Param("id") long id);

  List<WorkOrderRow> search(@Param("filter") WorkOrderFilter filter);
}
