import math
import pathlib
import sys


root = pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0, str(root))
from fusion import reciprocal_rank_fusion


assert sys.version_info[:2] == (3, 14)
rankings = {"sparse": ["A", "B", "C"], "dense": ["B", "D", "A"]}
fused = reciprocal_rank_fusion(rankings, allowed_doc_ids={"A", "B", "C", "D"})
assert [row[0] for row in fused] == ["B", "A", "D", "C"]
assert math.isclose(fused[0][1], 1 / 61 + 1 / 62)
assert fused[0][2] == {"sparse": 2, "dense": 1}
restricted = reciprocal_rank_fusion(rankings, allowed_doc_ids={"A", "C", "D"})
assert [row[0] for row in restricted] == ["A", "D", "C"]
assert all(row[0] != "B" for row in restricted)
print("PASS: hand RRF, deterministic tie rule, provenance and ACL filtering")
