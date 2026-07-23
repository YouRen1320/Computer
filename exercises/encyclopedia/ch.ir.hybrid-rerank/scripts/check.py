import pathlib
import sys


root = pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0, str(root))
from fusion_bug import fuse


sparse = {"A": 10.0, "B": 9.0}
dense = {"A": 0.1, "B": 0.9}
baseline = fuse(sparse, dense)
rescaled = fuse(sparse, {doc_id: score * 100 for doc_id, score in dense.items()})
if baseline != rescaled:
    raise AssertionError(f"EXPECTED RED: rank evidence is unchanged but raw-score scaling changed {baseline} to {rescaled}")
print("PASS: fusion is invariant to positive rescaling within one source")
