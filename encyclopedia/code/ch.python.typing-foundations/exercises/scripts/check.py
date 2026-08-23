"""Expected-red oracle: the exercise target must become strict-green."""

from __future__ import annotations

import ast
import os
import pathlib
import subprocess
import sys


root = pathlib.Path(__file__).resolve().parents[1]
environment = dict(os.environ)
environment["UV_NO_PROGRESS"] = "1"
completed = subprocess.run(
    [
        "uvx",
        "--from",
        "mypy==2.3.0",
        "mypy",
        "--strict",
        "--no-incremental",
        "--cache-dir=/dev/null",
        "--python-version",
        "3.14",
        "--show-error-codes",
        str(root / "typed_summary.py"),
    ],
    capture_output=True,
    text=True,
    env=environment,
    check=False,
)
assert completed.returncode == 0, (
    "EXPECTED RED: repair contracts without Any/ignore:\n"
    + completed.stdout
    + completed.stderr
)

target = root / "typed_summary.py"
source = target.read_text(encoding="utf-8")
tree = ast.parse(source, filename=str(target))
assert "# type: ignore" not in source and "# mypy: ignore-errors" not in source, (
    "forbidden type-checker suppression"
)
assert not any(
    isinstance(node, ast.Name) and node.id == "Any"
    or isinstance(node, ast.Attribute) and node.attr == "Any"
    for node in ast.walk(tree)
), "Any is not an implementation of this exercise contract"

functions = {
    node.name: node
    for node in tree.body
    if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef))
}
assert set(functions) == {"display_name", "collect_priorities", "count_active"}
assert ast.unparse(functions["display_name"].args.args[0].annotation) == "str | None"
assert ast.unparse(functions["display_name"].returns) == "str"
assert ast.unparse(functions["collect_priorities"].returns) == "list[int]"
assert ast.unparse(functions["count_active"].returns) == "int"
assert all(
    not (isinstance(node, ast.Name) and node.id == "object")
    for node in ast.walk(tree)
), "object would erase the required precise contracts"

sys.path.insert(0, str(root))
from typed_summary import collect_priorities, count_active, display_name

assert display_name(None) == "未命名"
assert display_name("pump") == "PUMP"
assert collect_priorities() == [1, 2, 4]
assert count_active() == 2
print("PASS: public typing exercise is strict-green and behavior-green without escape hatches")
