import logging

import pytest

from work_order_service import MemoryRepository, WorkOrder, WorkOrderNotFound, close_order


@pytest.fixture
def repository() -> MemoryRepository:
    # function 作用域让每个测试获得独立、可预测的仓储状态。
    return MemoryRepository([WorkOrder(7, "ASSIGNED"), WorkOrder(8, "CLOSED")])


@pytest.mark.parametrize(
    ("order_id", "expected_save_count"),
    [(7, 1), (8, 0)],
    ids=["assigned-closes", "closed-is-idempotent"],
)
def test_close_order(repository: MemoryRepository, order_id: int, expected_save_count: int) -> None:
    result = close_order(repository, order_id, "corr-example")

    assert result.status == "CLOSED"
    assert len(repository.saved_ids) == expected_save_count


def test_missing_order_has_safe_correlated_log(
    repository: MemoryRepository, caplog: pytest.LogCaptureFixture
) -> None:
    with caplog.at_level(logging.WARNING), pytest.raises(WorkOrderNotFound):
        close_order(repository, 404, "corr-missing")

    record = caplog.records[-1]
    assert record.getMessage() == "work_order_not_found"
    assert record.correlation_id == "corr-missing"
    assert "secret-token" not in caplog.text
