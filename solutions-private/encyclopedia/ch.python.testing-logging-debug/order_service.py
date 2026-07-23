import logging

logger = logging.getLogger(__name__)


class RepositoryUnavailable(RuntimeError):
    pass


class BrokenRepository:
    def save_closed(self, order_id: int) -> None:
        raise RepositoryUnavailable(f"repository unavailable for {order_id}")


def close_order(repository: BrokenRepository, order_id: int) -> str:
    try:
        repository.save_closed(order_id)
    except RepositoryUnavailable:
        logger.exception("close_order_failed", extra={"order_id": order_id})
        raise
    return "CLOSED"
