"""Compare implementation output with a direct hand formula."""

import math
import pathlib
import sys


root = pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0, str(root))
from lexical import InvertedIndex, tokenize


assert sys.version_info[:2] == (3, 14)
documents = {
    "D1": "pump motor noise",
    "D2": "pump leak seal",
    "D3": "motor vibration",
}
index = InvertedIndex(documents)
assert tokenize("Pump, PUMP! 42") == ["pump", "pump", "42"]
assert index.postings["pump"] == {"D1": 1, "D2": 1}
assert index.document_frequency("pump") == 2
assert index.document_frequency("noise") == 1
assert math.isclose(index.average_length, 8 / 3)

idf_pump = math.log(1 + (3 - 2 + 0.5) / (2 + 0.5))
idf_noise = math.log(1 + (3 - 1 + 0.5) / (1 + 0.5))
normalizer = 1.2 * (1 - 0.75 + 0.75 * (3 / (8 / 3)))
saturation = 2.2 / (1 + normalizer)
expected_d1 = (idf_pump + idf_noise) * saturation
parts = index.explain("pump noise", "D1")
assert [part.term for part in parts] == ["pump", "noise"]
assert all(part.tf == 1 for part in parts)
assert math.isclose(index.score("pump noise", "D1"), expected_d1, rel_tol=1e-12)
assert index.score("pump pump noise", "D1") == index.score("pump noise", "D1")
assert [doc_id for doc_id, _ in index.search("pump noise")] == ["D1", "D2", "D3"]
assert index.search("absent") == [("D1", 0), ("D2", 0), ("D3", 0)]
print("PASS: tokenization, postings, df, average length, hand BM25 and tie rule")
