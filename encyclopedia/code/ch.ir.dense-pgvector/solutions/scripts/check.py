import pathlib
import sys


root = pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0, str(root))
from store_fixed import VectorStore


store = VectorStore("model-a@1", 3)
store.add("C1", "model-a@1", (1.0, 0.0, 0.0))
for space_id, vector, message in (
    ("model-b@9", (1.0, 0.0, 0.0), "embedding space mismatch"),
    ("model-a@1", (1.0, 0.0), "dimension mismatch"),
):
    try:
        store.add("bad", space_id, vector)
    except ValueError as error:
        assert str(error) == message
    else:
        raise AssertionError(message)
assert store.rows == [("C1", (1.0, 0.0, 0.0))]
print("PASS: model space and dimension are both enforced")
