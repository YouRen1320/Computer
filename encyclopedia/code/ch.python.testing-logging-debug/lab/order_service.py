from dataclasses import dataclass


@dataclass
class WorkOrder:
    order_id: int
    status: str


class MemoryRepository:
    def __init__(self) -> None:
        self.orders: dict[int, WorkOrder] = {}

    def add(self, order: WorkOrder) -> None:
        self.orders[order.order_id] = order

    def count(self) -> int:
        return len(self.orders)


def register(repository: MemoryRepository, order_id: int) -> WorkOrder:
    order = WorkOrder(order_id, "CREATED")
    repository.add(order)
    return order
