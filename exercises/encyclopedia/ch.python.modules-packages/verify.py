from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parent / "src"))
from factorycare_training.priority import normalize_priority

assert normalize_priority(4) == 4
try:
    normalize_priority(0)
except ValueError:
    pass
else:
    raise AssertionError("越界优先级必须抛出 ValueError；请完成 TODO")
print("PASS modules public exercise")
