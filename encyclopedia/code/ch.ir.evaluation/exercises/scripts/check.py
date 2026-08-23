import pathlib
import sys


root = pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0, str(root))
from ndcg_bug import ndcg


actual = ndcg(["irrelevant", "best"], {"irrelevant": 0, "best": 3}, 2)
if not 0 < actual < 1:
    raise AssertionError(f"EXPECTED RED: reversed relevance cannot have nDCG={actual}")
print("PASS: nDCG compares against an independently ideal ranking")
