from __future__ import annotations

import logging
from dataclasses import dataclass

logger = logging.getLogger(__name__)


@dataclass
class WorkOrder:
    order_id: int
    status: str


class WorkOrderNotFound(LookupError):
    pass


class MemoryRepository:
    def __init__(self, orders: list[WorkOrder]) -> None:
        self._orders = {order.order_id: order for order in orders}
        self.saved_ids: list[int] = []

    def get(self, order_id: int) -> WorkOrder | None:
        return self._orders.get(order_id)

    def save(self, order: WorkOrder) -> None:
        self.saved_ids.append(order.order_id)


def close_order(repository: MemoryRepository, order_id: int, correlation_id: str) -> WorkOrder:
    order = repository.get(order_id)
    if order is None:
        logger.warning(
            "work_order_not_found",
            extra={"order_id": order_id, "correlation_id": correlation_id},
        )
        raise WorkOrderNotFound(order_id)

    if order.status != "CLOSED":
        order.status = "CLOSED"
        repository.save(order)
        logger.info(
            "work_order_closed",
            extra={"order_id": order_id, "correlation_id": correlation_id},
        )
    return order
