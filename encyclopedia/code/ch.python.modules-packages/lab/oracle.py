from pathlib import Path
import os
import subprocess
import sys

ROOT = Path(__file__).resolve().parent
FIXTURES = ROOT / "fixtures"
environment = os.environ | {"PYTHONPATH": str(FIXTURES)}

cycle = subprocess.run(
    [sys.executable, "-c", "import cycle.a"],
    cwd=ROOT,
    env=environment,
    text=True,
    capture_output=True,
    check=False,
)
assert cycle.returncode != 0, "故意循环导入必须失败"
assert "partially initialized module" in cycle.stderr
assert "DEFAULT_ASSIGNEE" in cycle.stderr

repaired = subprocess.run(
    [
        sys.executable,
        "-c",
        "from repaired.assignment import assign; print(assign())",
    ],
    cwd=ROOT,
    env=environment,
    text=True,
    capture_output=True,
    check=False,
)
assert repaired.returncode == 0, repaired.stderr
assert repaired.stdout == "assigned to tech-7\n"
assert repaired.stderr == ""
print("PASS modules lab: circular import classified and acyclic repair verified")
