package com.factorycare.workorder.persistence;

import java.time.OffsetDateTime;
import java.util.List;

/** Typed input keeps XML property paths stable and separates values from SQL structure. */
public record WorkOrderFilter(
    WorkOrderStatus status,
    Long assigneeId,
    String keyword,
    OffsetDateTime createdFrom,
    List<Long> ids,
    WorkOrderSort sort
) {}
