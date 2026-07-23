import logging

import pytest

from order_service import BrokenRepository, RepositoryUnavailable, close_order


def test_repository_failure_is_not_reported_as_business_success(
    caplog: pytest.LogCaptureFixture,
) -> None:
    with caplog.at_level(logging.ERROR), pytest.raises(RepositoryUnavailable):
        close_order(BrokenRepository(), 41)

    assert "close_order_failed" in caplog.text
    assert "token=" not in caplog.text
