import math
import pathlib
import sys


root = pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0, str(root))
from metrics import dcg_at_k, ndcg_at_k, precision_at_k, recall_at_k, reciprocal_rank


assert sys.version_info[:2] == (3, 14)
ranking = ["D2", "D1", "D3", "D4"]
grades = {"D1": 2, "D2": 0, "D3": 1, "D4": 0}
assert precision_at_k(ranking, grades, 3) == 2 / 3
assert recall_at_k(ranking, grades, 3) == 1
assert reciprocal_rank(ranking, grades) == 1 / 2
hand_dcg = 3 / math.log2(3) + 1 / math.log2(4)
hand_idcg = 3 / math.log2(2) + 1 / math.log2(3)
assert math.isclose(dcg_at_k(ranking, grades, 3), hand_dcg, rel_tol=1e-12)
assert math.isclose(ndcg_at_k(ranking, grades, 3), hand_dcg / hand_idcg, rel_tol=1e-12)
try:
    recall_at_k(ranking, {"D1": 0}, 3)
except ValueError as error:
    assert "undefined" in str(error)
else:
    raise AssertionError("recall without relevant judgments must be explicit")
print("PASS: P@k, R@k, RR, DCG and nDCG agree with the hand oracle")
