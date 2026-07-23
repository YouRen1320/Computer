import asyncio

import pytest


async def collect(events) -> tuple[str, str]:
    chunks: list[str] = []
    try:
        async for event in events:
            if event["type"] == "delta":
                chunks.append(event["text"])
            elif event["type"] == "completed":
                return "".join(chunks), "completed"
        return "".join(chunks), "partial"
    except asyncio.CancelledError:
        raise


async def scripted(items):
    for item in items:
        await asyncio.sleep(0)
        yield item


@pytest.mark.asyncio
async def test_terminal_contract() -> None:
    assert await collect(scripted([{"type": "delta", "text": "a"}])) == ("a", "partial")
    assert await collect(scripted([{"type": "delta", "text": "a"}, {"type": "completed"}])) == ("a", "completed")


@pytest.mark.asyncio
async def test_cancel_propagates() -> None:
    async def blocked():
        await asyncio.sleep(10)
        yield {"type": "completed"}
    task = asyncio.create_task(collect(blocked()))
    await asyncio.sleep(0)
    task.cancel()
    with pytest.raises(asyncio.CancelledError):
        await task
