"""Private reference for the asyncio cancellation exercise."""

import asyncio
import time


async def cancellable_worker(
    started: asyncio.Event,
    release: asyncio.Event,
    cleaned: list[str],
) -> None:
    started.set()
    try:
        await release.wait()
    finally:
        cleaned.append("worker")


async def cancel_and_wait(task: asyncio.Task[None]) -> bool:
    task.cancel("reference cancellation")
    try:
        await task
    except asyncio.CancelledError:
        return task.cancelled()
    return False


def blocking_lookup(value: int) -> int:
    time.sleep(0.03)
    return value * 2


async def run_blocking_lookup(value: int) -> int:
    return await asyncio.to_thread(blocking_lookup, value)
