"""Stable behavioral oracle for the editable asyncio starter."""

from __future__ import annotations

import asyncio
import importlib.util
import pathlib
import sys
import traceback
from types import ModuleType


def load_submission(path: pathlib.Path) -> ModuleType:
    spec = importlib.util.spec_from_file_location("asyncio_submission", path)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"cannot load {path}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


async def inspect_contract(module: ModuleType) -> list[str]:
    problems: list[str] = []
    started = asyncio.Event()
    release = asyncio.Event()
    cleaned: list[str] = []
    task = asyncio.create_task(
        module.cancellable_worker(started, release, cleaned),
        name="owned-worker",
    )
    await started.wait()
    observed = await module.cancel_and_wait(task)
    await asyncio.sleep(0)
    if not observed:
        problems.append("owner-did-not-observe-cancellation")
    if not task.cancelled():
        problems.append("worker-swallowed-cancellation")
    if cleaned != ["worker"]:
        problems.append("cleanup-not-exactly-once")
    if not task.done():
        task.cancel()
        try:
            await task
        except asyncio.CancelledError:
            pass

    heartbeat = asyncio.Event()

    async def tick() -> None:
        await asyncio.sleep(0)
        heartbeat.set()

    ticker = asyncio.create_task(tick(), name="event-loop-heartbeat")
    value = await module.run_blocking_lookup(21)
    event_loop_progressed = heartbeat.is_set()
    await ticker
    if value != 42:
        problems.append("blocking-result-changed")
    if not event_loop_progressed:
        problems.append("blocking-call-ran-on-event-loop")

    current = asyncio.current_task()
    leftovers = [candidate for candidate in asyncio.all_tasks() if candidate is not current]
    if leftovers:
        problems.append("unowned-task-left-running")
        for leftover in leftovers:
            leftover.cancel()
    return problems


def main() -> int:
    try:
        root = pathlib.Path(__file__).resolve().parents[1]
        module = load_submission(root / "exercise.py")
        problems = asyncio.run(inspect_contract(module))
    except Exception:  # Non-contract failure: preserve diagnostics for exit 43 mapping.
        traceback.print_exc()
        return 70

    if problems:
        print(
            "EXPECTED_PYTHON_ASYNCIO_CANCELLATION_RED problems=" + ",".join(problems),
            file=sys.stderr,
        )
        return 1
    print("PYTHON_ASYNCIO_CANCELLATION_EXERCISE_PASS checks=6")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
