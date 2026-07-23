import math
import pathlib
import sys


root = pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0, str(root))
from ndcg_fixed import ndcg


grades = {"irrelevant": 0, "good": 1, "best": 3}
bad = ndcg(["irrelevant", "good", "best"], grades, 3)
perfect = ndcg(["best", "good", "irrelevant"], grades, 3)
assert 0 < bad < 1
assert math.isclose(perfect, 1.0)
assert ndcg(["x"], {"x": 0}, 1) == 0
print("PASS: IDCG is independent, perfect is one and reversed ranking is lower")
