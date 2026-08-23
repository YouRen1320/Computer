package com.factorycare.workorder.persistence;

import java.time.OffsetDateTime;

/** Read-only work-order projection returned by the mapper resultMap. */
public record WorkOrderRow(
    Long id,
    String number,
    String title,
    WorkOrderStatus status,
    Long assigneeId,
    OffsetDateTime createdAt
) {}
