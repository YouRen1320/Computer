#!/usr/bin/env bash
set -euo pipefail

# 这是故障注入练习：找到三个并发边界错误后稳定返回 41。
set +e
python3 - <<'PY'
import ast
import asyncio
import sys


BROKEN_SOURCE = '''
import asyncio
import time

async def swallowed_cancellation(event):
    try:
        await event.wait()
    except asyncio.CancelledError:
        return "cancelled-but-reported-success"

async def discarded_task(event):
    asyncio.create_task(event.wait())

async def blocked_loop():
    time.sleep(0.01)
'''


def dotted_name(node: ast.AST) -> str:
    if isinstance(node, ast.Name):
        return node.id
    if isinstance(node, ast.Attribute):
        parent = dotted_name(node.value)
        return f"{parent}.{node.attr}" if parent else node.attr
    return ""


tree = ast.parse(BROKEN_SOURCE, filename="broken_async.py")
findings: list[str] = []

for node in ast.walk(tree):
    if isinstance(node, ast.ExceptHandler) and dotted_name(node.type) == "asyncio.CancelledError":
        if not any(isinstance(child, ast.Raise) for child in ast.walk(node)):
            findings.append("cancellation swallowed: CancelledError handler does not re-raise")
    if isinstance(node, ast.Expr) and isinstance(node.value, ast.Call):
        if dotted_name(node.value.func) == "asyncio.create_task":
            findings.append("task has no owner: create_task result is discarded")
    if isinstance(node, ast.Call) and dotted_name(node.func) == "time.sleep":
        findings.append("event loop blocked: time.sleep is called inside async code")

namespace: dict[str, object] = {}
exec(compile(tree, "broken_async.py", "exec"), namespace)


async def prove_swallowing() -> None:
    event = asyncio.Event()
    task = asyncio.create_task(namespace["swallowed_cancellation"](event))
    await asyncio.sleep(0)
    task.cancel()
    result = await task
    assert result == "cancelled-but-reported-success"
    assert not task.cancelled()


asyncio.run(prove_swallowing())
assert sorted(findings) == sorted([
    "cancellation swallowed: CancelledError handler does not re-raise",
    "task has no owner: create_task result is discarded",
    "event loop blocked: time.sleep is called inside async code",
])
for finding in findings:
    print(f"[EXPECTED FAILURE] {finding}", file=sys.stderr)
sys.exit(41)
PY
exercise_status=$?
set -e

if [[ "$exercise_status" -ne 41 ]]; then
  echo "exercise oracle drift: expected exit 41, got $exercise_status" >&2
  exit 42
fi
exit 41
