#!/usr/bin/env bash
set -euo pipefail

python3 - <<'PY'
import asyncio
import sys


async def load_part(
    name: str,
    started: asyncio.Event,
    release: asyncio.Event,
    cleaned: list[str],
) -> str:
    """等待可控事件，确保示例不依赖随机器调度。"""
    started.set()
    try:
        await release.wait()
        return f"{name}:ready"
    finally:
        cleaned.append(name)


async def main() -> None:
    release = asyncio.Event()
    started = {name: asyncio.Event() for name in ("order", "device", "index")}
    cleaned: list[str] = []

    async with asyncio.TaskGroup() as group:
        tasks = {
            name: group.create_task(
                load_part(name, started[name], release, cleaned),
                name=f"load-{name}",
            )
            for name in started
        }
        await asyncio.gather(*(event.wait() for event in started.values()))
        release.set()

    assert {name: task.result() for name, task in tasks.items()} == {
        "order": "order:ready",
        "device": "device:ready",
        "index": "index:ready",
    }
    assert sorted(cleaned) == ["device", "index", "order"]
    current = asyncio.current_task()
    assert [task for task in asyncio.all_tasks() if task is not current] == []


assert sys.version_info[:2] == (3, 14), sys.version
asyncio.run(main())
print("PASS asyncio example: TaskGroup owns all tasks; cleanup ran; no task leaked")
PY
