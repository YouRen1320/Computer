import json
import pathlib
import sys


root = pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0, str(root))
from ann_fixture import Row, rank, recall_at_k


assert sys.version_info[:2] == (3, 14)
manifest = json.loads((root / "service_evidence.json").read_text())
assert manifest["evidence_kind"] == "controlled_fixture_manifest"
assert manifest["real_service_verified"] is False
assert "real_query_plan" in manifest["not_verified_here"]
assert manifest["postgresql_target"] == "18.4" and manifest["pgvector_target"] == "0.8.2"
sql = (root / "schema.sql").read_text()
for required in (
    "CREATE EXTENSION IF NOT EXISTS vector",
    "embedding vector(3) NOT NULL",
    "USING hnsw (embedding vector_cosine_ops)",
    "WHERE space_id = $1 AND chunk_id = ANY($2)",
    "ORDER BY embedding <=> $3::vector ASC",
    "EXPLAIN (ANALYZE, BUFFERS, FORMAT JSON)",
):
    assert required in sql

rows = [
    Row("C1", "space-v1", (1.0, 0.0, 0.0)),
    Row("C2", "space-v1", (0.9, 0.1, 0.0)),
    Row("C3", "space-v1", (0.8, 0.2, 0.0)),
    Row("C4", "space-v1", (0.0, 1.0, 0.0)),
    Row("C5", "space-v2", (1.0, 0.0, 0.0)),
]
allowed = {"C1", "C2", "C3", "C4"}
exact = rank(rows, (1.0, 0.0, 0.0), space_id="space-v1", allowed_ids=allowed, limit=3)
# Simulate an ANN candidate miss by withholding C2; this is not an HNSW claim.
approximate_candidates = [row for row in rows if row.chunk_id != "C2"]
approximate = rank(approximate_candidates, (1.0, 0.0, 0.0), space_id="space-v1", allowed_ids=allowed, limit=3)
assert exact == ["C1", "C2", "C3"]
assert approximate == ["C1", "C3", "C4"]
assert recall_at_k(exact, approximate, 3) == 2 / 3
assert "C5" not in exact
restricted = rank(rows, (1.0, 0.0, 0.0), space_id="space-v1", allowed_ids={"C3", "C4"}, limit=2)
assert restricted == ["C3", "C4"]
print("PASS (CONTROLLED FIXTURE ONLY): math, SQL contract, space/ACL filters and recall@3")
