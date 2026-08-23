import asyncio

import pytest

from exercise import AuthenticationFailed, RetryableTransport, collect, should_retry


async def scripted(items):
    for item in items:
        await asyncio.sleep(0)
        yield item


@pytest.mark.asyncio
async def test_completion_requires_terminal_event_and_tool_is_only_proposed() -> None:
    partial = await collect(scripted([
        {"type": "delta", "text": "a"},
        {"type": "tool_call", "name": "close_order", "arguments": {}},
    ]))
    assert partial == {"text": "a", "status": "partial", "tool_calls": [
        {"type": "tool_call", "name": "close_order", "arguments": {}}]}
    completed = await collect(scripted([
        {"type": "delta", "text": "a"}, {"type": "response.completed"},
    ]))
    assert completed["status"] == "completed"


@pytest.mark.asyncio
async def test_cancellation_propagates() -> None:
    async def blocked():
        await asyncio.sleep(10)
        yield {"type": "response.completed"}

    task = asyncio.create_task(collect(blocked()))
    await asyncio.sleep(0)
    task.cancel()
    with pytest.raises(asyncio.CancelledError):
        await task


def test_retry_is_bounded_and_classified() -> None:
    retryable = RetryableTransport("reset")
    assert should_retry(retryable, attempt=1, max_attempts=3)
    assert not should_retry(retryable, attempt=3, max_attempts=3)
    assert not should_retry(AuthenticationFailed("401"), attempt=1, max_attempts=3)
