import pathlib
import sys

import pandas as pd


root = pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0, str(root))
from hybrid import Case, ablation


assert sys.version_info[:2] == (3, 14)
assert pd.__version__ == "3.0.5"
cases = (
    Case("Q1", {"A": 3, "C": 1}, ("A", "C", "D"), ("B", "A", "C"), {"A": .9, "C": .7, "B": .2, "D": .1}, frozenset("ABCDE")),
    Case("Q2", {"E": 3, "B": 2}, ("B", "D", "E"), ("E", "B", "A"), {"E": .9, "B": .8, "D": .2, "A": .1}, frozenset("ABCDE")),
    Case("Q3", {"G": 3}, ("D", "G"), ("G", "F"), {"G": .9, "D": .1, "F": .2}, frozenset("DFG")),
)
latency = {"sparse": 5, "dense": 8, "hybrid": 11, "rerank": 17}
frame = ablation(cases, latency, budget_ms=20)
assert len(frame) == 12
assert set(frame["measurement_kind"]) == {"controlled_budget_fixture_not_wall_clock"}
assert frame["within_budget"].all()
means = frame.groupby("method")["ndcg_at_3"].mean().to_dict()
assert means["hybrid"] > means["sparse"]
assert means["hybrid"] > means["dense"]
assert means["rerank"] > means["hybrid"]
q2 = frame.loc[frame["query_id"] == "Q2"].set_index("method")
assert q2.loc["hybrid", "ranking"][:2] == ("B", "E")
assert q2.loc["rerank", "ranking"][:2] == ("E", "B")

# ACL regression: X has the largest scripted score but is not allowed and cannot reappear.
restricted_case = Case("ACL", {"A": 1}, ("X", "A"), ("X", "A"), {"X": 99.0, "A": 1.0}, frozenset({"A"}))
restricted = ablation((restricted_case,), latency, budget_ms=20)
assert all("X" not in ranking for ranking in restricted["ranking"])
print("PASS (CONTROLLED FIXTURE ONLY): four-way ablation, gain, budget label and ACL invariant")
