import asyncio

import pytest

from solution import AuthenticationFailed, RetryableTransport, collect, should_retry


async def scripted(items):
    for item in items:
        await asyncio.sleep(0)
        yield item


@pytest.mark.asyncio
async def test_terminal_partial_and_cancel_contracts() -> None:
    assert (await collect(scripted([{"type": "delta", "text": "a"}])))["status"] == "partial"
    assert (await collect(scripted([{"type": "response.completed"}])))["status"] == "completed"
    async def blocked():
        await asyncio.sleep(10)
        yield {"type": "response.completed"}
    task = asyncio.create_task(collect(blocked())); await asyncio.sleep(0); task.cancel()
    with pytest.raises(asyncio.CancelledError):
        await task


def test_retry_contract() -> None:
    assert should_retry(RetryableTransport("reset"), attempt=1, max_attempts=3)
    assert not should_retry(RetryableTransport("reset"), attempt=3, max_attempts=3)
    assert not should_retry(AuthenticationFailed("401"), attempt=1, max_attempts=3)
