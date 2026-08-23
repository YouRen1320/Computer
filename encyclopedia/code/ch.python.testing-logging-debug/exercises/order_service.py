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
        # 练习缺口：只记日志却继续返回成功，调用者失去了失败事实。
        logger.exception("close_order_failed", extra={"order_id": order_id})
    return "CLOSED"
