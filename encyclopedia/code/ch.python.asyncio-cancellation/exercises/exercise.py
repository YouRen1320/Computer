"""Editable asyncio cancellation exercise."""

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
    except asyncio.CancelledError:
        # TODO：完成必要清理后仍要保持取消语义。
        return
    finally:
        cleaned.append("worker")


async def cancel_and_wait(task: asyncio.Task[None]) -> bool:
    # TODO：所有者要取消并等待；返回 task 是否以 cancelled 状态结束。
    task.cancel("exercise cancellation")
    return False


def blocking_lookup(value: int) -> int:
    time.sleep(0.03)
    return value * 2


async def run_blocking_lookup(value: int) -> int:
    # TODO：把同步阻塞调用移出事件循环线程。
    return blocking_lookup(value)
