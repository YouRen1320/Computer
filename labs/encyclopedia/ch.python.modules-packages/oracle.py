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

# 修复模型：共享值由下层提供，两个消费者只依赖下层。
namespace: dict[str, object] = {}
exec(
    "DEFAULT_ASSIGNEE='tech-7'\n"
    "def render(name): return f'assigned to {name}'\n"
    "def assign(): return render(DEFAULT_ASSIGNEE)\n",
    namespace,
)
assert namespace["assign"]() == "assigned to tech-7"  # type: ignore[operator]
print("PASS modules lab: circular import classified and acyclic repair verified")
