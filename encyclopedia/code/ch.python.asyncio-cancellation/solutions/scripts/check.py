from __future__ import annotations

import asyncio
import importlib.util
import pathlib


root = pathlib.Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("asyncio_solution", root / "solution.py")
assert spec is not None and spec.loader is not None
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


async def main() -> None:
    started = asyncio.Event()
    release = asyncio.Event()
    cleaned: list[str] = []
    task = asyncio.create_task(module.cancellable_worker(started, release, cleaned))
    await started.wait()
    assert await module.cancel_and_wait(task)
    assert task.cancelled()
    assert cleaned == ["worker"]

    heartbeat = asyncio.Event()

    async def tick() -> None:
        await asyncio.sleep(0)
        heartbeat.set()

    ticker = asyncio.create_task(tick())
    assert await module.run_blocking_lookup(21) == 42
    assert heartbeat.is_set()
    await ticker
    current = asyncio.current_task()
    assert [candidate for candidate in asyncio.all_tasks() if candidate is not current] == []


asyncio.run(main())
print("PASS private asyncio solution: cancellation, ownership and blocking isolation")
