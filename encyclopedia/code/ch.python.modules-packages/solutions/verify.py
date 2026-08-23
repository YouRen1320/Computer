from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parent / "src"))
from factorycare_training import normalize_priority

assert [normalize_priority(value) for value in (1, 3, 5)] == [1, 3, 5]
for invalid in (0, 6):
    try:
        normalize_priority(invalid)
    except ValueError:
        continue
    raise AssertionError(f"expected ValueError for {invalid}")
print("PASS modules private solution")
