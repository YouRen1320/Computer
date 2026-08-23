import pytest

from order_service import MemoryRepository, register


@pytest.fixture
def repository() -> MemoryRepository:
    # 不把可变实例放到模块级；每个 case 从空仓储开始。
    return MemoryRepository()


@pytest.mark.parametrize("order_id", [1, 2, 99], ids=lambda value: f"order-{value}")
def test_registers_one_order_in_isolated_repository(
    repository: MemoryRepository, order_id: int
) -> None:
    result = register(repository, order_id)

    assert result.order_id == order_id
    assert repository.count() == 1


def test_a_new_case_does_not_observe_previous_cases(repository: MemoryRepository) -> None:
    assert repository.count() == 0
