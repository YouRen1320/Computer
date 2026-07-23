"""Verify corpus invariants and a golden ranking."""

import pathlib
import sys


root = pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0, str(root))
from retrieval import BM25Index


assert sys.version_info[:2] == (3, 14)
documents = {
    "WO-101": "pump motor noise bearing",
    "WO-102": "pump leak seal pressure",
    "WO-103": "sensor temperature alarm calibration",
    "WO-104": "motor vibration bearing inspection",
    "WO-105": "network gateway offline cable",
}
index = BM25Index(documents)
assert index.n == 5
assert index.avgdl == 4
assert sum(index.lengths.values()) == 20
assert all(len(posting) <= index.n for posting in index.postings.values())
assert index.postings["pump"] == {"WO-101": 1, "WO-102": 1}
assert index.postings["bearing"] == {"WO-101": 1, "WO-104": 1}

hits = index.search("pump bearing noise")
assert [hit.doc_id for hit in hits] == ["WO-101", "WO-102", "WO-104", "WO-103", "WO-105"]
assert [piece[0] for piece in hits[0].contributions] == ["pump", "bearing", "noise"]
assert index.search("pump pump bearing")[0].score == index.search("pump bearing")[0].score
assert all(hit.score == 0 for hit in index.search("unknown-token"))
try:
    index.search("pump", limit=0)
except ValueError as error:
    assert str(error) == "limit must be positive"
else:
    raise AssertionError("non-positive limit must fail")
print("PASS: five-document index invariants, explanations, boundaries and golden rank")
