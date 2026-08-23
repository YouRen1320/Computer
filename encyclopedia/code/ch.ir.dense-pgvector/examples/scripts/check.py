import math
import pathlib
import sys


root = pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0, str(root))
from vectors import EmbeddedChunk, cosine_distance, exact_cosine_search, inner_product, l2_distance


assert sys.version_info[:2] == (3, 14)
assert l2_distance((1.0, 0.0), (0.0, 1.0)) == math.sqrt(2)
assert inner_product((1.0, 2.0), (3.0, 4.0)) == 11
assert math.isclose(cosine_distance((1.0, 0.0), (1.0, 1.0)), 1 - 1 / math.sqrt(2))
rows = [
    EmbeddedChunk("C1", "space-v1", (1.0, 0.0)),
    EmbeddedChunk("C2", "space-v1", (1.0, 1.0)),
    EmbeddedChunk("C3", "space-v1", (0.0, 1.0)),
    EmbeddedChunk("C4", "space-v2", (1.0, 0.0)),
]
assert [item[0] for item in exact_cosine_search(rows, (1.0, 0.0), "space-v1", 3)] == ["C1", "C2", "C3"]
try:
    cosine_distance((0.0, 0.0), (1.0, 0.0))
except ValueError as error:
    assert "zero vector" in str(error)
else:
    raise AssertionError("zero-vector cosine must fail")
print("PASS: hand distances, exact rank, space filter and zero-vector boundary")
