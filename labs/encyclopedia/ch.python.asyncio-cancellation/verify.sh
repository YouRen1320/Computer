#!/usr/bin/env bash
set -euo pipefail

python3 - <<'PY'
import asyncio
import sys
from collections.abc import Awaitable, Callable


async def controlled_worker(
    name: str,
    started: asyncio.Event,
    release: asyncio.Event,
    cleaned: list[str],
    *,
    fail: bool = False,
) -> str:
    started.set()
    try:
        await release.wait()
        if fail:
            raise RuntimeError(f"{name} failed")
        return name
    finally:
        cleaned.append(name)


async def assert_no_leaked_tasks() -> None:
    await asyncio.sleep(0)
    current = asyncio.current_task()
    leaked = [task for task in asyncio.all_tasks() if task is not current]
    assert leaked == [], [task.get_name() for task in leaked]


async def success_case() -> None:
    release = asyncio.Event()
    starts = [asyncio.Event() for _ in range(3)]
    cleaned: list[str] = []
    async with asyncio.TaskGroup() as group:
        tasks = [
            group.create_task(
                controlled_worker(str(index), starts[index], release, cleaned),
                name=f"success-{index}",
            )
            for index in range(3)
        ]
        await asyncio.gather(*(event.wait() for event in starts))
        release.set()
    assert [task.result() for task in tasks] == ["0", "1", "2"]
    assert sorted(cleaned) == ["0", "1", "2"]
    await assert_no_leaked_tasks()


async def child_failure_case() -> None:
    fail_release = asyncio.Event()
    never_release = asyncio.Event()
    starts = [asyncio.Event() for _ in range(3)]
    cleaned: list[str] = []
    caught: ExceptionGroup | None = None
    try:
        async with asyncio.TaskGroup() as group:
            group.create_task(
                controlled_worker("bad", starts[0], fail_release, cleaned, fail=True),
                name="failing-child",
            )
            group.create_task(
                controlled_worker("sibling-a", starts[1], never_release, cleaned),
                name="sibling-a",
            )
            group.create_task(
                controlled_worker("sibling-b", starts[2], never_release, cleaned),
                name="sibling-b",
            )
            await asyncio.gather(*(event.wait() for event in starts))
            fail_release.set()
    except* RuntimeError as group_error:
        caught = group_error
    assert caught is not None
    assert [str(error) for error in caught.exceptions] == ["bad failed"]
    assert sorted(cleaned) == ["bad", "sibling-a", "sibling-b"]
    await assert_no_leaked_tasks()


async def timeout_case() -> None:
    started = asyncio.Event()
    never_release = asyncio.Event()
    cleaned: list[str] = []
    timed_out = False
    try:
        async with asyncio.timeout(0.05):
            async with asyncio.TaskGroup() as group:
                group.create_task(
                    controlled_worker("timeout", started, never_release, cleaned),
                    name="timeout-child",
                )
                await started.wait()
                await never_release.wait()
    except TimeoutError:
        timed_out = True
    assert timed_out
    assert cleaned == ["timeout"]
    await assert_no_leaked_tasks()


async def cancellable_parent(
    starts: list[asyncio.Event],
    release: asyncio.Event,
    cleaned: list[str],
) -> None:
    async with asyncio.TaskGroup() as group:
        for index in range(2):
            group.create_task(
                controlled_worker(f"cancel-{index}", starts[index], release, cleaned),
                name=f"cancel-child-{index}",
            )
        await asyncio.gather(*(event.wait() for event in starts))
        await release.wait()


async def parent_cancellation_case() -> None:
    starts = [asyncio.Event(), asyncio.Event()]
    never_release = asyncio.Event()
    cleaned: list[str] = []
    parent = asyncio.create_task(
        cancellable_parent(starts, never_release, cleaned),
        name="owned-parent",
    )
    await asyncio.gather(*(event.wait() for event in starts))
    parent.cancel("lab cancellation")
    try:
        await parent
    except asyncio.CancelledError:
        pass
    else:
        raise AssertionError("parent must propagate CancelledError")
    assert sorted(cleaned) == ["cancel-0", "cancel-1"]
    await assert_no_leaked_tasks()


async def main() -> None:
    cases: list[tuple[str, Callable[[], Awaitable[None]]]] = [
        ("success", success_case),
        ("child failure", child_failure_case),
        ("timeout", timeout_case),
        ("parent cancellation", parent_cancellation_case),
    ]
    for name, case in cases:
        await case()
        print(f"PASS {name}")


assert sys.version_info[:2] == (3, 14), sys.version
asyncio.run(main())
print("PASS asyncio lab: success/boundary/failure cleanup and task-leak oracles hold")
PY
