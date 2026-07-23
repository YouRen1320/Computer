import pathlib
import sys

import pandas as pd


root = pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0, str(root))
from evaluate import QueryCase, dataset_hash, report


assert sys.version_info[:2] == (3, 14)
assert pd.__version__ == "3.0.5"
cases = (
    QueryCase("Q1", "pump bearing noise", ("W1", "W2", "W4"), {"W1": 3, "W2": 0, "W4": 2}, "specific"),
    QueryCase("Q2", "device alarm", ("W5", "W3", "W2"), {"W3": 2, "W5": 0}, "ambiguous"),
    QueryCase("Q3", "gateway cable offline", ("W2", "W1", "W4"), {"W5": 3, "W2": 0}, "zero-recall"),
)
digest = dataset_hash(cases)
assert digest == dataset_hash(tuple(reversed(cases)))
assert len(digest) == 64
frame = report(cases)
assert frame["query_id"].tolist() == ["Q1", "Q2", "Q3"]
assert frame.loc[0, "recall_at_3"] == 1
assert frame.loc[1, "mrr"] == 0.5
assert frame.loc[2, "recall_at_3"] == 0
assert frame.loc[1, "unjudged_top_k"] == ("W2",)
assert frame.loc[2, "unjudged_top_k"] == ("W1", "W4")
zero_recall = frame.loc[frame["recall_at_3"] == 0, "query_id"].tolist()
ambiguous = frame.loc[frame["slice"] == "ambiguous", "query_id"].tolist()
assert zero_recall == ["Q3"] and ambiguous == ["Q2"]
assert frame["recall_at_3"].mean() == 2 / 3
print(f"PASS: frozen={digest[:12]} per-query metrics, zero-recall and ambiguity slices")
