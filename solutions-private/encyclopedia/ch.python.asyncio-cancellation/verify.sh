#!/usr/bin/env bash
set -euo pipefail

python3 - <<'PY'
import asyncio
import sys
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
        # 只做必要的本地清理，随后保持取消语义。
        raise
    finally:
        cleaned.append("worker")


def blocking_lookup(value: int) -> int:
    time.sleep(0.01)
    return value * 2


async def main() -> None:
    started = asyncio.Event()
    never_release = asyncio.Event()
    cleaned: list[str] = []

    async with asyncio.TaskGroup() as group:
        task = group.create_task(
            cancellable_worker(started, never_release, cleaned),
            name="owned-worker",
        )
        await started.wait()
        task.cancel("reference cancellation")

    assert task.cancelled()
    assert cleaned == ["worker"]

    # 线程阻塞调用不直接占用事件循环线程；结果仍被当前协程拥有并等待。
    assert await asyncio.to_thread(blocking_lookup, 21) == 42
    current = asyncio.current_task()
    assert [candidate for candidate in asyncio.all_tasks() if candidate is not current] == []


assert sys.version_info[:2] == (3, 14), sys.version
asyncio.run(main())
print("PASS private asyncio solution: cancellation propagates, ownership is explicit, blocking work is isolated")
PY
