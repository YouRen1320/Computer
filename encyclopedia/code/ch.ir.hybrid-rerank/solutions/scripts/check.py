import pathlib
import sys


root = pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0, str(root))
from fusion_fixed import fuse


sparse = {"A": 10.0, "B": 9.0, "C": 1.0}
dense = {"A": 0.1, "B": 0.9, "D": 0.5}
baseline = fuse(sparse, dense)
assert baseline == fuse(sparse, {doc_id: score * 100 for doc_id, score in dense.items()})
assert baseline == fuse({doc_id: score * 0.001 for doc_id, score in sparse.items()}, dense)
assert set(baseline) == {"A", "B", "C", "D"}
print("PASS: RRF is scale-invariant and preserves the candidate union")
